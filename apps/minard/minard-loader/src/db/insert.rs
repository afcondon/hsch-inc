use duckdb::{params, Connection};

use crate::error::Result;
use crate::model::{
    ChildDeclaration, Declaration, Module, PackageDependency, PackageVersion, Project, Snapshot,
    SnapshotPackage,
};

/// Insert or get a project, returning its ID
pub fn get_or_create_project(
    conn: &Connection,
    id: i64,
    name: &str,
    repo_path: Option<&str>,
) -> Result<i64> {
    // First try to find existing project
    let existing: std::result::Result<i64, _> = conn.query_row(
        "SELECT id FROM projects WHERE name = ?",
        params![name],
        |row| row.get(0),
    );

    match existing {
        Ok(id) => Ok(id),
        Err(duckdb::Error::QueryReturnedNoRows) => {
            // Insert new project
            conn.execute(
                "INSERT INTO projects (id, name, repo_path) VALUES (?, ?, ?)",
                params![id, name, repo_path],
            )?;
            Ok(id)
        }
        Err(e) => Err(e.into()),
    }
}

/// Insert a project
pub fn insert_project(conn: &Connection, project: &Project) -> Result<()> {
    conn.execute(
        "INSERT OR IGNORE INTO projects (id, name, repo_path, description) VALUES (?, ?, ?, ?)",
        params![
            project.id,
            project.name,
            project.repo_path,
            project.description
        ],
    )?;
    Ok(())
}

/// Insert a snapshot
pub fn insert_snapshot(conn: &Connection, snapshot: &Snapshot) -> Result<()> {
    conn.execute(
        "INSERT OR IGNORE INTO snapshots (id, project_id, git_hash, git_ref, label) VALUES (?, ?, ?, ?, ?)",
        params![
            snapshot.id,
            snapshot.project_id,
            snapshot.git_hash,
            snapshot.git_ref,
            snapshot.label
        ],
    )?;
    Ok(())
}

/// Insert snapshot package associations
pub fn insert_snapshot_packages(conn: &Connection, packages: &[SnapshotPackage]) -> Result<()> {
    let mut stmt = conn.prepare(
        "INSERT OR IGNORE INTO snapshot_packages (snapshot_id, package_version_id, source, is_direct)
         VALUES (?, ?, ?, ?)",
    )?;

    for pkg in packages {
        stmt.execute(params![
            pkg.snapshot_id,
            pkg.package_version_id,
            pkg.source,
            pkg.is_direct
        ])?;
    }

    Ok(())
}

/// Insert a batch of package versions
pub fn insert_package_versions(conn: &Connection, packages: &[PackageVersion]) -> Result<()> {
    let mut stmt = conn.prepare(
        "INSERT OR IGNORE INTO package_versions
         (id, name, version, description, license, repository, source)
         VALUES (?, ?, ?, ?, ?, ?, ?)",
    )?;

    for pkg in packages {
        stmt.execute(params![
            pkg.id,
            pkg.name,
            pkg.version,
            pkg.description,
            pkg.license,
            pkg.repository,
            pkg.source,
        ])?;
    }

    Ok(())
}

/// Insert package versions and return map of (name, version) -> actual ID
/// This handles the case where packages may already exist with different IDs
pub fn insert_package_versions_with_ids(
    conn: &Connection,
    packages: &[PackageVersion],
) -> Result<std::collections::HashMap<(String, String), i64>> {
    use std::collections::HashMap;

    // First insert all packages (ignoring duplicates)
    insert_package_versions(conn, packages)?;

    // Then query back all actual IDs
    let mut result = HashMap::new();
    let mut stmt = conn.prepare(
        "SELECT id, name, version FROM package_versions WHERE name = ? AND version = ?",
    )?;

    for pkg in packages {
        let id: i64 = stmt.query_row(params![&pkg.name, &pkg.version], |row| row.get(0))?;
        result.insert((pkg.name.clone(), pkg.version.clone()), id);
    }

    Ok(result)
}

/// Insert a batch of package dependencies
pub fn insert_package_dependencies(conn: &Connection, deps: &[PackageDependency]) -> Result<()> {
    let mut stmt = conn.prepare(
        "INSERT OR IGNORE INTO package_dependencies (dependent_id, dependency_name)
         VALUES (?, ?)",
    )?;

    for dep in deps {
        stmt.execute(params![dep.dependent_id, dep.dependency_name,])?;
    }

    Ok(())
}

/// Insert a batch of modules
pub fn insert_modules(conn: &Connection, modules: &[Module]) -> Result<()> {
    let mut stmt = conn.prepare(
        "INSERT OR IGNORE INTO modules
         (id, package_version_id, name, path, comments)
         VALUES (?, ?, ?, ?, ?)",
    )?;

    for module in modules {
        stmt.execute(params![
            module.id,
            module.package_version_id,
            module.name,
            module.path,
            module.comments,
        ])?;
    }

    Ok(())
}

/// Insert a batch of declarations
pub fn insert_declarations(conn: &Connection, decls: &[Declaration]) -> Result<()> {
    let mut stmt = conn.prepare(
        "INSERT OR IGNORE INTO declarations
         (id, module_id, name, kind, type_signature, type_ast,
          data_decl_type, type_arguments, roles, superclasses, fundeps,
          synonym_type, comments, source_span)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
    )?;

    for decl in decls {
        let type_ast_json = decl.type_ast.as_ref().map(|v| v.to_string());
        let type_args_json = decl.type_arguments.as_ref().map(|v| v.to_string());
        let roles_json = decl.roles.as_ref().map(|v| v.to_string());
        let superclasses_json = decl.superclasses.as_ref().map(|v| v.to_string());
        let fundeps_json = decl.fundeps.as_ref().map(|v| v.to_string());
        let synonym_json = decl.synonym_type.as_ref().map(|v| v.to_string());
        let source_span_json = decl.source_span.as_ref().map(|v| v.to_string());

        stmt.execute(params![
            decl.id,
            decl.module_id,
            decl.name,
            decl.kind,
            decl.type_signature,
            type_ast_json,
            decl.data_decl_type,
            type_args_json,
            roles_json,
            superclasses_json,
            fundeps_json,
            synonym_json,
            decl.comments,
            source_span_json,
        ])?;
    }

    Ok(())
}

/// Insert a batch of child declarations
pub fn insert_child_declarations(conn: &Connection, children: &[ChildDeclaration]) -> Result<()> {
    let mut stmt = conn.prepare(
        "INSERT OR IGNORE INTO child_declarations
         (id, declaration_id, name, kind, type_signature, type_ast,
          constructor_args, instance_chain, instance_constraints, comments, source_span)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
    )?;

    for child in children {
        let type_ast_json = child.type_ast.as_ref().map(|v| v.to_string());
        let args_json = child.constructor_args.as_ref().map(|v| v.to_string());
        let chain_json = child.instance_chain.as_ref().map(|v| v.to_string());
        let constraints_json = child.instance_constraints.as_ref().map(|v| v.to_string());
        let source_span_json = child.source_span.as_ref().map(|v| v.to_string());

        stmt.execute(params![
            child.id,
            child.declaration_id,
            child.name,
            child.kind,
            child.type_signature,
            type_ast_json,
            args_json,
            chain_json,
            constraints_json,
            child.comments,
            source_span_json,
        ])?;
    }

    Ok(())
}

/// Get max IDs from existing database tables
/// Returns (max_project, max_snapshot, max_package, max_module, max_decl, max_child)
pub fn get_max_ids(conn: &Connection) -> Result<(i64, i64, i64, i64, i64, i64)> {
    let max_proj: i64 = conn
        .query_row("SELECT COALESCE(MAX(id), 0) FROM projects", [], |row| {
            row.get(0)
        })
        .unwrap_or(0);

    let max_snap: i64 = conn
        .query_row("SELECT COALESCE(MAX(id), 0) FROM snapshots", [], |row| {
            row.get(0)
        })
        .unwrap_or(0);

    let max_pkg: i64 = conn
        .query_row(
            "SELECT COALESCE(MAX(id), 0) FROM package_versions",
            [],
            |row| row.get(0),
        )
        .unwrap_or(0);

    let max_mod: i64 = conn
        .query_row("SELECT COALESCE(MAX(id), 0) FROM modules", [], |row| {
            row.get(0)
        })
        .unwrap_or(0);

    let max_decl: i64 = conn
        .query_row(
            "SELECT COALESCE(MAX(id), 0) FROM declarations",
            [],
            |row| row.get(0),
        )
        .unwrap_or(0);

    let max_child: i64 = conn
        .query_row(
            "SELECT COALESCE(MAX(id), 0) FROM child_declarations",
            [],
            |row| row.get(0),
        )
        .unwrap_or(0);

    Ok((max_proj, max_snap, max_pkg, max_mod, max_decl, max_child))
}

/// Get existing package ID by name and version
pub fn get_package_id(conn: &Connection, name: &str, version: &str) -> Result<Option<i64>> {
    let result: std::result::Result<i64, _> = conn.query_row(
        "SELECT id FROM package_versions WHERE name = ? AND version = ?",
        params![name, version],
        |row| row.get(0),
    );

    match result {
        Ok(id) => Ok(Some(id)),
        Err(duckdb::Error::QueryReturnedNoRows) => Ok(None),
        Err(e) => Err(e.into()),
    }
}
