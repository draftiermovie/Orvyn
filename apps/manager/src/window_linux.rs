//! Linux fallback for the native Win32 manager window.
//!
//! The full Win32 control set in `window.rs` is Windows-only. On Linux the
//! web interface (`window` / `menu`) is the supported UI, so this module keeps
//! the same public surface and reports that the native window is unavailable.
use crate::core::{self, Result};
use std::path::PathBuf;

pub fn error(text: &str) {
    eprintln!("{text}");
}

pub fn run(_root: PathBuf) -> Result<()> {
    Err("The native manager window is only available on Windows. Run `orvyn-manager window` for the web interface.".into())
}

pub fn smoke_test(_root: PathBuf) -> Result<()> {
    Err("The native manager smoke test is only available on Windows.".into())
}

pub fn pick_model_file() -> Option<PathBuf> {
    // Use the desktop file chooser when one is available.
    let output = core::hidden("zenity")
        .args([
            "--file-selection",
            "--title=Select a GGUF model",
            "--file-filter=GGUF model | *.gguf",
        ])
        .output()
        .ok()?;
    if !output.status.success() {
        return None;
    }
    let path = String::from_utf8_lossy(&output.stdout).trim().to_string();
    if path.is_empty() {
        None
    } else {
        Some(PathBuf::from(path))
    }
}
