use serde_json::Value;

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
        format!(
            "Loaded {} packages, {} modules, {} declarations, {} children in {}ms ({} parse errors)",
            self.packages_loaded,
            self.modules_loaded,
            self.declarations_loaded,
            self.child_declarations_loaded,
            self.elapsed_ms,
            self.parse_errors
        )
    }
}
