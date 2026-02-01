use rayon::prelude::*;
use serde_json::Value;
use std::collections::HashMap;
use std::path::Path;
use std::sync::Mutex;
use std::time::Instant;

use crate::db::{IdGenerator, get_max_ids, insert_child_declarations, insert_declarations, insert_modules, insert_package_dependencies, insert_package_versions};
use crate::error::Result;
use crate::model::{ChildDeclaration, Declaration, LoadStats, Module, PackageDependency, PackageVersion, ParsedModule};
use crate::parse::{DocsJson, SpagoLock, render_type};
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

    /// Load a project into the database
    pub fn load(
        &self,
        conn: &duckdb::Connection,
        project_path: &Path,
        project_name: &str,
        progress: &ProgressReporter,
    ) -> Result<LoadStats> {
        let start = Instant::now();
        let mut stats = LoadStats::default();

        // Phase 1: Discovery
        progress.set_message("Discovering project structure...");
        let discovery = ProjectDiscovery::discover(project_path)?;

        if self.verbose {
            eprintln!(
                "Found {} docs.json files in {}",
                discovery.module_count(),
                discovery.output_dir.display()
            );
        }

        // Phase 2: Parse spago.lock
        progress.set_message("Parsing spago.lock...");
        let spago_lock = SpagoLock::from_path(&discovery.spago_lock_path)?;

        // Initialize ID generator from existing database
        let (max_pkg, max_mod, max_decl, max_child) = get_max_ids(conn)?;
        self.id_gen
            .init_from_db(max_pkg, max_mod, max_decl, max_child);

        // Phase 3: Create package versions
        progress.set_message("Creating package versions...");
        let packages = spago_lock.all_packages();
        let mut package_map: HashMap<String, i64> = HashMap::new();
        let mut package_versions = Vec::new();
        let mut package_deps = Vec::new();

        for pkg_info in &packages {
            let pkg_id = self.id_gen.next_package_id();
            package_map.insert(pkg_info.name.clone(), pkg_id);

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

        // Insert packages
        insert_package_versions(conn, &package_versions)?;
        stats.packages_loaded = package_versions.len();

        // Create package dependencies (second pass after all packages exist)
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

        // Phase 4: Parse docs.json files in parallel
        progress.set_message("Parsing docs.json files...");
        progress.set_total(discovery.module_count() as u64);

        let parse_errors = Mutex::new(0usize);

        // For M1, we use a simple package assignment:
        // All modules go under a single "workspace" package representing the project
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
        insert_package_versions(conn, &[workspace_pkg])?;
        stats.packages_loaded += 1;

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

        // Phase 5: Insert into database
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
                    instance_chain: None, // Not in docs.json
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
