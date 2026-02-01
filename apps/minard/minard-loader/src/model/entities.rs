use serde_json::Value;

/// A project - a codebase being analyzed
#[derive(Debug, Clone)]
pub struct Project {
    pub id: i64,
    pub name: String,
    pub repo_path: Option<String>,
    pub description: Option<String>,
}

/// A snapshot - a point-in-time analysis of a project
#[derive(Debug, Clone)]
pub struct Snapshot {
    pub id: i64,
    pub project_id: i64,
    pub git_hash: Option<String>,
    pub git_ref: Option<String>,
    pub label: Option<String>,
}

/// Snapshot package association
#[derive(Debug, Clone)]
pub struct SnapshotPackage {
    pub snapshot_id: i64,
    pub package_version_id: i64,
    pub source: String, // "registry" | "workspace" | "local"
    pub is_direct: bool,
}

/// A package version - the core identity in the schema
#[derive(Debug, Clone)]
pub struct PackageVersion {
    pub id: i64,
    pub name: String,
    pub version: String,
    pub description: Option<String>,
    pub license: Option<String>,
    pub repository: Option<String>,
    pub source: String, // "registry" | "local" | "git"
}

/// A module within a package version
#[derive(Debug, Clone)]
pub struct Module {
    pub id: i64,
    pub package_version_id: i64,
    pub name: String,
    pub path: Option<String>,
    pub comments: Option<String>,
}

/// A top-level declaration in a module
#[derive(Debug, Clone)]
pub struct Declaration {
    pub id: i64,
    pub module_id: i64,
    pub name: String,
    pub kind: String,
    pub type_signature: Option<String>,
    pub type_ast: Option<Value>,
    pub data_decl_type: Option<String>,
    pub type_arguments: Option<Value>,
    pub roles: Option<Value>,
    pub superclasses: Option<Value>,
    pub fundeps: Option<Value>,
    pub synonym_type: Option<Value>,
    pub comments: Option<String>,
    pub source_span: Option<Value>,
}

/// A child declaration (constructor, instance, class member)
#[derive(Debug, Clone)]
pub struct ChildDeclaration {
    pub id: i64,
    pub declaration_id: i64,
    pub name: String,
    pub kind: String,
    pub type_signature: Option<String>,
    pub type_ast: Option<Value>,
    pub constructor_args: Option<Value>,
    pub instance_chain: Option<Value>,
    pub instance_constraints: Option<Value>,
    pub comments: Option<String>,
    pub source_span: Option<Value>,
}

/// Package dependency relationship
#[derive(Debug, Clone)]
pub struct PackageDependency {
    pub dependent_id: i64,
    pub dependency_name: String,
}

/// Results from parsing a docs.json file
#[derive(Debug)]
pub struct ParsedModule {
    pub module: Module,
    pub declarations: Vec<Declaration>,
    pub child_declarations: Vec<ChildDeclaration>,
}

/// Statistics from a load operation
#[derive(Debug, Default)]
pub struct LoadStats {
    pub project_name: String,
    pub snapshot_label: Option<String>,
    pub packages_loaded: usize,
    pub modules_loaded: usize,
    pub declarations_loaded: usize,
    pub child_declarations_loaded: usize,
    pub dependencies_loaded: usize,
    pub parse_errors: usize,
    pub elapsed_ms: u64,
}

impl LoadStats {
    pub fn report(&self) -> String {
        let label = self
            .snapshot_label
            .as_ref()
            .map(|l| format!(" ({})", l))
            .unwrap_or_default();
        format!(
            "Loaded {}{}: {} packages, {} modules, {} declarations, {} children in {}ms ({} parse errors)",
            self.project_name,
            label,
            self.packages_loaded,
            self.modules_loaded,
            self.declarations_loaded,
            self.child_declarations_loaded,
            self.elapsed_ms,
            self.parse_errors
        )
    }

    /// Merge stats from multiple loads
    pub fn merge(&mut self, other: &LoadStats) {
        self.packages_loaded += other.packages_loaded;
        self.modules_loaded += other.modules_loaded;
        self.declarations_loaded += other.declarations_loaded;
        self.child_declarations_loaded += other.child_declarations_loaded;
        self.dependencies_loaded += other.dependencies_loaded;
        self.parse_errors += other.parse_errors;
    }
}

/// Aggregate statistics from scanning multiple projects
#[derive(Debug, Default)]
pub struct ScanStats {
    pub projects_loaded: usize,
    pub projects_skipped: usize,
    pub total_packages: usize,
    pub total_modules: usize,
    pub total_declarations: usize,
    pub total_children: usize,
    pub total_parse_errors: usize,
    pub elapsed_ms: u64,
}

impl ScanStats {
    pub fn add(&mut self, stats: &LoadStats) {
        self.projects_loaded += 1;
        self.total_packages += stats.packages_loaded;
        self.total_modules += stats.modules_loaded;
        self.total_declarations += stats.declarations_loaded;
        self.total_children += stats.child_declarations_loaded;
        self.total_parse_errors += stats.parse_errors;
    }

    pub fn report(&self) -> String {
        format!(
            "Scanned {} projects ({} skipped): {} packages, {} modules, {} declarations, {} children in {}ms ({} parse errors)",
            self.projects_loaded,
            self.projects_skipped,
            self.total_packages,
            self.total_modules,
            self.total_declarations,
            self.total_children,
            self.elapsed_ms,
            self.total_parse_errors
        )
    }
}
