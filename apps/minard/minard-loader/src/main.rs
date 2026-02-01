use anyhow::Context;
use clap::Parser;
use duckdb::Connection;
use std::fs;

use minard_loader::{
    db::{drop_all_tables, get_stats, init_schema},
    loader::LoadPipeline,
    progress::ProgressReporter,
    Cli, Commands,
};

fn main() -> anyhow::Result<()> {
    let cli = Cli::parse();

    match cli.command {
        Commands::Init { fresh, database } => {
            println!("Initializing database: {}", database.display());

            if fresh && database.exists() {
                println!("Removing existing database (--fresh)...");
                fs::remove_file(&database)?;
                // Also remove WAL file if exists
                let wal = database.with_extension("duckdb.wal");
                if wal.exists() {
                    fs::remove_file(&wal)?;
                }
            }

            let conn = Connection::open(&database)
                .with_context(|| format!("Failed to open database: {}", database.display()))?;

            if !fresh {
                // Drop tables if they exist (in case of partial init)
                drop_all_tables(&conn)?;
            }

            init_schema(&conn)?;

            println!("Database initialized successfully!");
        }

        Commands::Load {
            project_path,
            database,
            name,
            verbose,
            quiet,
        } => {
            // Determine project name
            let project_name = name.unwrap_or_else(|| {
                project_path
                    .file_name()
                    .and_then(|n| n.to_str())
                    .map(|s| s.to_string())
                    .unwrap_or_else(|| "unknown".to_string())
            });

            if !quiet {
                println!("Loading project '{}' from {}", project_name, project_path.display());
                println!("Database: {}", database.display());
            }

            // Initialize database if it doesn't exist
            if !database.exists() {
                if !quiet {
                    println!("Database not found, initializing...");
                }
                let conn = Connection::open(&database)?;
                init_schema(&conn)?;
            }

            let conn = Connection::open(&database)
                .with_context(|| format!("Failed to open database: {}", database.display()))?;

            let progress = ProgressReporter::new(quiet);
            let pipeline = LoadPipeline::new(verbose);

            let stats = pipeline
                .load(&conn, &project_path, &project_name, &progress)
                .with_context(|| format!("Failed to load project: {}", project_path.display()))?;

            progress.finish();

            if !quiet {
                println!("\n{}", stats.report());
            }
        }

        Commands::Stats { database } => {
            if !database.exists() {
                anyhow::bail!("Database not found: {}", database.display());
            }

            let conn = Connection::open(&database)
                .with_context(|| format!("Failed to open database: {}", database.display()))?;

            let stats = get_stats(&conn)?;
            println!("{}", stats.report());
        }
    }

    Ok(())
}
