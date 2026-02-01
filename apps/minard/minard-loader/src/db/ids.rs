use std::sync::atomic::{AtomicI64, Ordering};

/// Thread-safe ID generator for parallel processing
#[derive(Debug)]
pub struct IdGenerator {
    project_counter: AtomicI64,
    snapshot_counter: AtomicI64,
    package_counter: AtomicI64,
    module_counter: AtomicI64,
    declaration_counter: AtomicI64,
    child_counter: AtomicI64,
}

impl IdGenerator {
    pub fn new() -> Self {
        Self {
            project_counter: AtomicI64::new(0),
            snapshot_counter: AtomicI64::new(0),
            package_counter: AtomicI64::new(0),
            module_counter: AtomicI64::new(0),
            declaration_counter: AtomicI64::new(0),
            child_counter: AtomicI64::new(0),
        }
    }

    /// Initialize counters from existing database max IDs
    pub fn init_from_db(
        &self,
        max_project: i64,
        max_snapshot: i64,
        max_package: i64,
        max_module: i64,
        max_decl: i64,
        max_child: i64,
    ) {
        self.project_counter.store(max_project, Ordering::SeqCst);
        self.snapshot_counter.store(max_snapshot, Ordering::SeqCst);
        self.package_counter.store(max_package, Ordering::SeqCst);
        self.module_counter.store(max_module, Ordering::SeqCst);
        self.declaration_counter.store(max_decl, Ordering::SeqCst);
        self.child_counter.store(max_child, Ordering::SeqCst);
    }

    pub fn next_project_id(&self) -> i64 {
        self.project_counter.fetch_add(1, Ordering::SeqCst) + 1
    }

    pub fn next_snapshot_id(&self) -> i64 {
        self.snapshot_counter.fetch_add(1, Ordering::SeqCst) + 1
    }

    pub fn next_package_id(&self) -> i64 {
        self.package_counter.fetch_add(1, Ordering::SeqCst) + 1
    }

    pub fn next_module_id(&self) -> i64 {
        self.module_counter.fetch_add(1, Ordering::SeqCst) + 1
    }

    pub fn next_declaration_id(&self) -> i64 {
        self.declaration_counter.fetch_add(1, Ordering::SeqCst) + 1
    }

    pub fn next_child_id(&self) -> i64 {
        self.child_counter.fetch_add(1, Ordering::SeqCst) + 1
    }

    /// Reserve a batch of IDs for parallel processing
    /// Returns (start_id, count) where IDs are start_id..start_id+count
    pub fn reserve_module_ids(&self, count: i64) -> i64 {
        self.module_counter.fetch_add(count, Ordering::SeqCst) + 1
    }

    pub fn reserve_declaration_ids(&self, count: i64) -> i64 {
        self.declaration_counter.fetch_add(count, Ordering::SeqCst) + 1
    }

    pub fn reserve_child_ids(&self, count: i64) -> i64 {
        self.child_counter.fetch_add(count, Ordering::SeqCst) + 1
    }
}

impl Default for IdGenerator {
    fn default() -> Self {
        Self::new()
    }
}
