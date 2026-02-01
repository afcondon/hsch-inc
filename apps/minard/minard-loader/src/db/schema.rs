use duckdb::Connection;

use crate::error::Result;

/// SQL schema for the M1 subset of unified-schema
/// We create only the tables needed for packages, modules, and declarations
const SCHEMA_SQL: &str = r#"
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
INSERT OR REPLACE INTO metadata (key, value) VALUES ('schema_version', 'm1-rust');
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
        DROP TABLE IF EXISTS package_dependencies;
        DROP TABLE IF EXISTS package_versions;
        DROP TABLE IF EXISTS metadata;
    "#,
    )?;
    Ok(())
}

/// Get database statistics
pub fn get_stats(conn: &Connection) -> Result<DbStats> {
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

    Ok(DbStats {
        package_count,
        module_count,
        declaration_count,
        child_count,
        dependency_count,
    })
}

#[derive(Debug)]
pub struct DbStats {
    pub package_count: i64,
    pub module_count: i64,
    pub declaration_count: i64,
    pub child_count: i64,
    pub dependency_count: i64,
}

impl DbStats {
    pub fn report(&self) -> String {
        format!(
            "Database contains:\n  {} packages\n  {} modules\n  {} declarations\n  {} child declarations\n  {} dependencies",
            self.package_count,
            self.module_count,
            self.declaration_count,
            self.child_count,
            self.dependency_count
        )
    }
}
