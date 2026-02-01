use duckdb::Connection;

use crate::error::Result;

/// SQL schema for minard-loader (M2)
/// Supports projects, snapshots, packages, modules, and declarations
const SCHEMA_SQL: &str = r#"
-- Projects: A codebase being analyzed
CREATE TABLE IF NOT EXISTS projects (
    id              INTEGER PRIMARY KEY,
    name            VARCHAR NOT NULL UNIQUE,
    repo_path       VARCHAR,
    description     TEXT,
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Snapshots: A point-in-time analysis of a project
CREATE TABLE IF NOT EXISTS snapshots (
    id              INTEGER PRIMARY KEY,
    project_id      INTEGER NOT NULL REFERENCES projects(id),
    git_hash        VARCHAR,
    git_ref         VARCHAR,
    label           VARCHAR,
    snapshot_at     TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(project_id, git_hash)
);

CREATE INDEX IF NOT EXISTS idx_snapshot_project ON snapshots(project_id);

-- Package versions - the core identity
CREATE TABLE IF NOT EXISTS package_versions (
    id              INTEGER PRIMARY KEY,
    name            VARCHAR NOT NULL,
    version         VARCHAR NOT NULL,
    description     TEXT,
    license         VARCHAR,
    repository      VARCHAR,
    source          VARCHAR DEFAULT 'registry',
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(name, version)
);

-- Package dependencies
CREATE TABLE IF NOT EXISTS package_dependencies (
    dependent_id    INTEGER NOT NULL REFERENCES package_versions(id),
    dependency_name VARCHAR NOT NULL,
    PRIMARY KEY (dependent_id, dependency_name)
);

-- Snapshot packages: Which package versions are used by a snapshot
CREATE TABLE IF NOT EXISTS snapshot_packages (
    snapshot_id         INTEGER NOT NULL REFERENCES snapshots(id),
    package_version_id  INTEGER NOT NULL REFERENCES package_versions(id),
    source              VARCHAR NOT NULL,
    is_direct           BOOLEAN DEFAULT FALSE,
    PRIMARY KEY (snapshot_id, package_version_id)
);

CREATE INDEX IF NOT EXISTS idx_snapshot_pkg_snapshot ON snapshot_packages(snapshot_id);
CREATE INDEX IF NOT EXISTS idx_snapshot_pkg_package ON snapshot_packages(package_version_id);

-- Modules
CREATE TABLE IF NOT EXISTS modules (
    id                  INTEGER PRIMARY KEY,
    package_version_id  INTEGER NOT NULL REFERENCES package_versions(id),
    name                VARCHAR NOT NULL,
    path                VARCHAR,
    comments            TEXT,
    UNIQUE(package_version_id, name)
);

CREATE INDEX IF NOT EXISTS idx_module_package ON modules(package_version_id);
CREATE INDEX IF NOT EXISTS idx_module_name ON modules(name);

-- Declarations
CREATE TABLE IF NOT EXISTS declarations (
    id              INTEGER PRIMARY KEY,
    module_id       INTEGER NOT NULL REFERENCES modules(id),
    name            VARCHAR NOT NULL,
    kind            VARCHAR NOT NULL,
    type_signature  TEXT,
    type_ast        JSON,
    data_decl_type  VARCHAR,
    type_arguments  JSON,
    roles           JSON,
    superclasses    JSON,
    fundeps         JSON,
    synonym_type    JSON,
    comments        TEXT,
    source_span     JSON,
    UNIQUE(module_id, name)
);

CREATE INDEX IF NOT EXISTS idx_decl_module ON declarations(module_id);
CREATE INDEX IF NOT EXISTS idx_decl_kind ON declarations(kind);
CREATE INDEX IF NOT EXISTS idx_decl_name ON declarations(name);

-- Child declarations (constructors, instances, class members)
CREATE TABLE IF NOT EXISTS child_declarations (
    id                  INTEGER PRIMARY KEY,
    declaration_id      INTEGER NOT NULL REFERENCES declarations(id),
    name                VARCHAR NOT NULL,
    kind                VARCHAR NOT NULL,
    type_signature      TEXT,
    type_ast            JSON,
    constructor_args    JSON,
    instance_chain      JSON,
    instance_constraints JSON,
    comments            TEXT,
    source_span         JSON
);

CREATE INDEX IF NOT EXISTS idx_child_decl_parent ON child_declarations(declaration_id);
CREATE INDEX IF NOT EXISTS idx_child_decl_kind ON child_declarations(kind);

-- Metadata table
CREATE TABLE IF NOT EXISTS metadata (
    key     VARCHAR PRIMARY KEY,
    value   VARCHAR
);

-- Insert schema version
INSERT OR REPLACE INTO metadata (key, value) VALUES ('schema_version', 'm2-rust');
INSERT OR REPLACE INTO metadata (key, value) VALUES ('created_at', CURRENT_TIMESTAMP);
"#;

/// Initialize the database schema
pub fn init_schema(conn: &Connection) -> Result<()> {
    conn.execute_batch(SCHEMA_SQL)?;
    Ok(())
}

/// Drop all tables (for fresh initialization)
pub fn drop_all_tables(conn: &Connection) -> Result<()> {
    conn.execute_batch(
        r#"
        DROP TABLE IF EXISTS child_declarations;
        DROP TABLE IF EXISTS declarations;
        DROP TABLE IF EXISTS modules;
        DROP TABLE IF EXISTS snapshot_packages;
        DROP TABLE IF EXISTS package_dependencies;
        DROP TABLE IF EXISTS package_versions;
        DROP TABLE IF EXISTS snapshots;
        DROP TABLE IF EXISTS projects;
        DROP TABLE IF EXISTS metadata;
    "#,
    )?;
    Ok(())
}

/// Get database statistics
pub fn get_stats(conn: &Connection) -> Result<DbStats> {
    let project_count: i64 = conn
        .query_row("SELECT COUNT(*) FROM projects", [], |row| row.get(0))
        .unwrap_or(0);

    let snapshot_count: i64 = conn
        .query_row("SELECT COUNT(*) FROM snapshots", [], |row| row.get(0))
        .unwrap_or(0);

    let package_count: i64 = conn
        .query_row("SELECT COUNT(*) FROM package_versions", [], |row| row.get(0))
        .unwrap_or(0);

    let module_count: i64 = conn
        .query_row("SELECT COUNT(*) FROM modules", [], |row| row.get(0))
        .unwrap_or(0);

    let declaration_count: i64 = conn
        .query_row("SELECT COUNT(*) FROM declarations", [], |row| row.get(0))
        .unwrap_or(0);

    let child_count: i64 = conn
        .query_row("SELECT COUNT(*) FROM child_declarations", [], |row| {
            row.get(0)
        })
        .unwrap_or(0);

    let dependency_count: i64 = conn
        .query_row("SELECT COUNT(*) FROM package_dependencies", [], |row| {
            row.get(0)
        })
        .unwrap_or(0);

    // Get project details for breakdown
    let project_details = get_project_details(conn).unwrap_or_default();

    Ok(DbStats {
        project_count,
        snapshot_count,
        package_count,
        module_count,
        declaration_count,
        child_count,
        dependency_count,
        project_details,
    })
}

/// Get detailed project/snapshot information
fn get_project_details(conn: &Connection) -> Result<Vec<ProjectDetail>> {
    let mut stmt = conn.prepare(
        "SELECT p.name, COUNT(s.id) as snapshot_count,
                (SELECT git_ref FROM snapshots WHERE project_id = p.id ORDER BY snapshot_at DESC LIMIT 1) as latest_ref,
                (SELECT SUBSTRING(git_hash, 1, 7) FROM snapshots WHERE project_id = p.id ORDER BY snapshot_at DESC LIMIT 1) as latest_hash
         FROM projects p
         LEFT JOIN snapshots s ON s.project_id = p.id
         GROUP BY p.id, p.name
         ORDER BY p.name",
    )?;

    let rows = stmt.query_map([], |row| {
        Ok(ProjectDetail {
            name: row.get(0)?,
            snapshot_count: row.get(1)?,
            latest_ref: row.get(2)?,
            latest_hash: row.get(3)?,
        })
    })?;

    let mut details = Vec::new();
    for row in rows {
        details.push(row?);
    }
    Ok(details)
}

#[derive(Debug, Clone)]
pub struct ProjectDetail {
    pub name: String,
    pub snapshot_count: i64,
    pub latest_ref: Option<String>,
    pub latest_hash: Option<String>,
}

#[derive(Debug)]
pub struct DbStats {
    pub project_count: i64,
    pub snapshot_count: i64,
    pub package_count: i64,
    pub module_count: i64,
    pub declaration_count: i64,
    pub child_count: i64,
    pub dependency_count: i64,
    pub project_details: Vec<ProjectDetail>,
}

impl DbStats {
    pub fn report(&self) -> String {
        let mut lines = vec![String::from("Database contains:")];

        if self.project_count > 0 {
            lines.push(format!("  {} projects", self.project_count));
            for proj in &self.project_details {
                let latest = match (&proj.latest_ref, &proj.latest_hash) {
                    (Some(ref_name), Some(hash)) => format!("latest: {}@{}", ref_name, hash),
                    (Some(ref_name), None) => format!("latest: {}", ref_name),
                    (None, Some(hash)) => format!("latest: {}", hash),
                    (None, None) => "no snapshots".to_string(),
                };
                lines.push(format!(
                    "    {}: {} snapshots ({})",
                    proj.name, proj.snapshot_count, latest
                ));
            }
        }

        lines.push(format!("  {} packages", self.package_count));
        lines.push(format!("  {} modules", self.module_count));
        lines.push(format!("  {} declarations", self.declaration_count));
        lines.push(format!("  {} child declarations", self.child_count));
        lines.push(format!("  {} dependencies", self.dependency_count));

        lines.join("\n")
    }
}
