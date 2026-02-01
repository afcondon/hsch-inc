use std::path::{Path, PathBuf};
use walkdir::WalkDir;

use crate::error::{LoaderError, Result};

/// Discovered project structure
#[derive(Debug)]
pub struct ProjectDiscovery {
    pub project_path: PathBuf,
    pub spago_lock_path: PathBuf,
    pub output_dir: PathBuf,
    pub docs_json_files: Vec<PathBuf>,
}

impl ProjectDiscovery {
    /// Discover a PureScript project at the given path
    pub fn discover(project_path: &Path) -> Result<Self> {
        if !project_path.exists() {
            return Err(LoaderError::ProjectNotFound(project_path.to_path_buf()));
        }

        let spago_lock_path = project_path.join("spago.lock");
        if !spago_lock_path.exists() {
            return Err(LoaderError::SpagoLockNotFound(spago_lock_path));
        }

        let output_dir = project_path.join("output");
        if !output_dir.exists() {
            return Err(LoaderError::OutputDirNotFound(output_dir));
        }

        // Find all docs.json files in output directory
        let docs_json_files = find_docs_json_files(&output_dir);

        Ok(Self {
            project_path: project_path.to_path_buf(),
            spago_lock_path,
            output_dir,
            docs_json_files,
        })
    }

    /// Get the number of discovered docs.json files
    pub fn module_count(&self) -> usize {
        self.docs_json_files.len()
    }
}

/// Find all docs.json files in the output directory
fn find_docs_json_files(output_dir: &Path) -> Vec<PathBuf> {
    let mut files = Vec::new();

    for entry in WalkDir::new(output_dir)
        .min_depth(2)
        .max_depth(2)
        .into_iter()
        .filter_map(|e| e.ok())
    {
        let path = entry.path();
        if path.file_name().map(|n| n == "docs.json").unwrap_or(false) {
            files.push(path.to_path_buf());
        }
    }

    files.sort();
    files
}

/// Extract module name from docs.json path
/// e.g., /path/to/output/Data.Maybe/docs.json -> "Data.Maybe"
pub fn module_name_from_path(docs_path: &Path) -> Option<String> {
    docs_path
        .parent()
        .and_then(|p| p.file_name())
        .and_then(|n| n.to_str())
        .map(|s| s.to_string())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_module_name_from_path() {
        let path = PathBuf::from("/foo/output/Data.Maybe/docs.json");
        assert_eq!(
            module_name_from_path(&path),
            Some("Data.Maybe".to_string())
        );
    }
}
