use duckdb::{params, Connection};

use crate::error::Result;
use crate::model::{ChildDeclaration, Declaration, Module, PackageDependency, PackageVersion};

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
pub fn get_max_ids(conn: &Connection) -> Result<(i64, i64, i64, i64)> {
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

    Ok((max_pkg, max_mod, max_decl, max_child))
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
