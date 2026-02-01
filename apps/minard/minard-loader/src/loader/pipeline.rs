use rayon::prelude::*;
use serde_json::Value;
use std::collections::HashMap;
use std::path::Path;
use std::sync::Mutex;
use std::time::Instant;

use crate::db::{
    get_max_ids, get_or_create_project, insert_child_declarations, insert_declarations,
    insert_modules, insert_package_dependencies, insert_package_versions_with_ids, insert_snapshot,
    insert_snapshot_packages, IdGenerator,
};
use crate::error::Result;
use crate::git::get_git_info;
use crate::model::{
    ChildDeclaration, Declaration, LoadStats, Module, PackageDependency, PackageVersion,
    ParsedModule, Snapshot, SnapshotPackage,
};
use crate::parse::{render_type, DocsJson, SpagoLock};
use crate::progress::ProgressReporter;

use super::discovery::ProjectDiscovery;

/// Main load pipeline
pub struct LoadPipeline {
    id_gen: IdGenerator,
    verbose: bool,
}

impl LoadPipeline {
    pub fn new(verbose: bool) -> Self {
        Self {
            id_gen: IdGenerator::new(),
            verbose,
        }
    }

    /// Initialize ID generator from database
    pub fn init_ids(&self, conn: &duckdb::Connection) -> Result<()> {
        let (max_proj, max_snap, max_pkg, max_mod, max_decl, max_child) = get_max_ids(conn)?;
        self.id_gen
            .init_from_db(max_proj, max_snap, max_pkg, max_mod, max_decl, max_child);
        Ok(())
    }

    /// Load a project into the database with project/snapshot tracking
    pub fn load(
        &self,
        conn: &duckdb::Connection,
        discovery: &ProjectDiscovery,
        project_name: &str,
        snapshot_label: Option<&str>,
        progress: &ProgressReporter,
    ) -> Result<LoadStats> {
        let start = Instant::now();
        let mut stats = LoadStats {
            project_name: project_name.to_string(),
            snapshot_label: snapshot_label.map(|s| s.to_string()),
            ..Default::default()
        };

        if self.verbose {
            eprintln!(
                "Found {} docs.json files in {}",
                discovery.module_count(),
                discovery.output_dir.display()
            );
        }

        // Phase 1: Get or create project
        progress.set_message("Creating project record...");
        let project_id = self.id_gen.next_project_id();
        let project_id = get_or_create_project(
            conn,
            project_id,
            project_name,
            discovery.project_path.to_str(),
        )?;

        // Phase 2: Get git info and create snapshot
        progress.set_message("Creating snapshot...");
        let git_info = get_git_info(&discovery.project_path);
        let snapshot_id = self.id_gen.next_snapshot_id();

        let label = snapshot_label
            .map(|s| s.to_string())
            .or_else(|| git_info.as_ref().and_then(|g| g.ref_name.clone()))
            .unwrap_or_else(|| "manual".to_string());

        let snapshot = Snapshot {
            id: snapshot_id,
            project_id,
            git_hash: git_info.as_ref().map(|g| g.hash.clone()),
            git_ref: git_info.as_ref().and_then(|g| g.ref_name.clone()),
            label: Some(label.clone()),
        };
        insert_snapshot(conn, &snapshot)?;
        stats.snapshot_label = Some(label);

        // Phase 3: Parse spago.lock
        progress.set_message("Parsing spago.lock...");
        let spago_lock = SpagoLock::from_path(&discovery.spago_lock_path)?;

        // Phase 4: Create package versions
        progress.set_message("Creating package versions...");
        let packages = spago_lock.all_packages();
        let mut package_versions = Vec::new();

        for pkg_info in &packages {
            let pkg_id = self.id_gen.next_package_id();
            package_versions.push(PackageVersion {
                id: pkg_id,
                name: pkg_info.name.clone(),
                version: pkg_info.version.clone(),
                description: None,
                license: None,
                repository: None,
                source: pkg_info.source.clone(),
            });
        }

        // Insert packages and get actual IDs (handles existing packages)
        let pkg_id_map = insert_package_versions_with_ids(conn, &package_versions)?;
        stats.packages_loaded = package_versions.len();

        // Build name -> actual_id map for dependencies
        let mut package_map: HashMap<String, i64> = HashMap::new();
        for pkg in &package_versions {
            if let Some(&actual_id) = pkg_id_map.get(&(pkg.name.clone(), pkg.version.clone())) {
                package_map.insert(pkg.name.clone(), actual_id);
            }
        }

        // Create package dependencies using actual IDs
        let mut package_deps = Vec::new();
        for pkg_info in &packages {
            if let Some(&pkg_id) = package_map.get(&pkg_info.name) {
                for dep_name in &pkg_info.dependencies {
                    package_deps.push(PackageDependency {
                        dependent_id: pkg_id,
                        dependency_name: dep_name.clone(),
                    });
                }
            }
        }

        insert_package_dependencies(conn, &package_deps)?;
        stats.dependencies_loaded = package_deps.len();

        // Create workspace package for local modules
        let workspace_pkg_id = self.id_gen.next_package_id();
        let workspace_pkg = PackageVersion {
            id: workspace_pkg_id,
            name: project_name.to_string(),
            version: "0.0.0".to_string(),
            description: Some(format!("Workspace package for {}", project_name)),
            license: None,
            repository: None,
            source: "workspace".to_string(),
        };
        let workspace_id_map = insert_package_versions_with_ids(conn, &[workspace_pkg.clone()])?;
        let workspace_pkg_id = *workspace_id_map
            .get(&(workspace_pkg.name, workspace_pkg.version))
            .unwrap_or(&workspace_pkg_id);
        stats.packages_loaded += 1;

        // Create snapshot_packages with actual IDs
        let mut snapshot_packages = Vec::new();
        for pkg in &package_versions {
            if let Some(&actual_id) = pkg_id_map.get(&(pkg.name.clone(), pkg.version.clone())) {
                snapshot_packages.push(SnapshotPackage {
                    snapshot_id,
                    package_version_id: actual_id,
                    source: pkg.source.clone(),
                    is_direct: false,
                });
            }
        }

        // Link workspace package to snapshot
        snapshot_packages.push(SnapshotPackage {
            snapshot_id,
            package_version_id: workspace_pkg_id,
            source: "workspace".to_string(),
            is_direct: true,
        });

        insert_snapshot_packages(conn, &snapshot_packages)?;

        // Phase 5: Parse docs.json files in parallel
        progress.set_message("Parsing docs.json files...");
        progress.set_total(discovery.module_count() as u64);

        let parse_errors = Mutex::new(0usize);

        let parsed_modules: Vec<ParsedModule> = discovery
            .docs_json_files
            .par_iter()
            .filter_map(|docs_path| {
                progress.inc(1);

                match self.parse_docs_json(docs_path, workspace_pkg_id) {
                    Ok(parsed) => Some(parsed),
                    Err(e) => {
                        if self.verbose {
                            eprintln!("Warning: Failed to parse {}: {}", docs_path.display(), e);
                        }
                        *parse_errors.lock().unwrap() += 1;
                        None
                    }
                }
            })
            .collect();

        stats.parse_errors = *parse_errors.lock().unwrap();

        // Phase 6: Insert into database
        progress.set_message("Inserting into database...");

        let mut all_modules = Vec::new();
        let mut all_declarations = Vec::new();
        let mut all_children = Vec::new();

        for parsed in parsed_modules {
            all_modules.push(parsed.module);
            all_declarations.extend(parsed.declarations);
            all_children.extend(parsed.child_declarations);
        }

        insert_modules(conn, &all_modules)?;
        stats.modules_loaded = all_modules.len();

        insert_declarations(conn, &all_declarations)?;
        stats.declarations_loaded = all_declarations.len();

        insert_child_declarations(conn, &all_children)?;
        stats.child_declarations_loaded = all_children.len();

        stats.elapsed_ms = start.elapsed().as_millis() as u64;

        Ok(stats)
    }

    /// Parse a single docs.json file
    fn parse_docs_json(&self, docs_path: &Path, package_id: i64) -> Result<ParsedModule> {
        let docs = DocsJson::from_path(docs_path)?;

        let module_id = self.id_gen.next_module_id();

        let module = Module {
            id: module_id,
            package_version_id: package_id,
            name: docs.name.clone(),
            path: docs_path
                .parent()
                .and_then(|p| p.file_name())
                .and_then(|n| n.to_str())
                .map(|s| s.to_string()),
            comments: docs.comments.clone(),
        };

        let mut declarations = Vec::new();
        let mut child_declarations = Vec::new();

        for decl in &docs.declarations {
            let decl_id = self.id_gen.next_declaration_id();

            // Render type signature
            let type_signature = decl.type_ast().map(render_type);

            // Convert type arguments to JSON
            let type_arguments: Option<Value> = decl.type_arguments().map(|args| {
                let arr: Vec<Value> = args
                    .iter()
                    .map(|arg| match arg {
                        crate::parse::docs::TypeArgument::Named(arr) => {
                            serde_json::json!(arr)
                        }
                        crate::parse::docs::TypeArgument::Value(v) => v.clone(),
                    })
                    .collect();
                Value::Array(arr)
            });

            declarations.push(Declaration {
                id: decl_id,
                module_id,
                name: decl.title.clone(),
                kind: decl.kind_str().to_string(),
                type_signature,
                type_ast: decl.type_ast().cloned(),
                data_decl_type: decl.data_decl_type().map(|s| s.to_string()),
                type_arguments,
                roles: decl.roles().map(|r| serde_json::to_value(r).unwrap()),
                superclasses: decl.superclasses().map(|s| Value::Array(s.clone())),
                fundeps: decl.fundeps().map(|f| Value::Array(f.clone())),
                synonym_type: match &decl.info {
                    crate::parse::docs::DeclarationInfo::TypeSynonym { type_info, .. } => {
                        type_info.clone()
                    }
                    _ => None,
                },
                comments: decl.comments.clone(),
                source_span: decl.source_span.as_ref().map(|s| {
                    serde_json::json!({
                        "start": s.start,
                        "end": s.end,
                        "name": s.name
                    })
                }),
            });

            // Process child declarations
            for child in &decl.children {
                let child_id = self.id_gen.next_child_id();

                let type_signature = match &child.info {
                    crate::parse::docs::ChildDeclarationInfo::Instance { type_info, .. } => {
                        type_info.as_ref().map(render_type)
                    }
                    crate::parse::docs::ChildDeclarationInfo::TypeClassMember { type_info } => {
                        type_info.as_ref().map(render_type)
                    }
                    _ => None,
                };

                child_declarations.push(ChildDeclaration {
                    id: child_id,
                    declaration_id: decl_id,
                    name: child.title.clone(),
                    kind: child.kind_str().to_string(),
                    type_signature,
                    type_ast: match &child.info {
                        crate::parse::docs::ChildDeclarationInfo::Instance { type_info, .. } => {
                            type_info.clone()
                        }
                        crate::parse::docs::ChildDeclarationInfo::TypeClassMember { type_info } => {
                            type_info.clone()
                        }
                        _ => None,
                    },
                    constructor_args: child.constructor_args().map(|a| Value::Array(a.clone())),
                    instance_chain: None,
                    instance_constraints: child
                        .instance_constraints()
                        .map(|c| Value::Array(c.clone())),
                    comments: child.comments.clone(),
                    source_span: child.source_span.as_ref().map(|s| {
                        serde_json::json!({
                            "start": s.start,
                            "end": s.end,
                            "name": s.name
                        })
                    }),
                });
            }
        }

        Ok(ParsedModule {
            module,
            declarations,
            child_declarations,
        })
    }
}
