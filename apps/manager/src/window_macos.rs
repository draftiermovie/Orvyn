//! macOS integration for the shared desktop webview.
use crate::core::{self, err, Result};
use std::{fs, os::unix::fs::PermissionsExt, path::PathBuf};

pub fn bundle_resources(exe: &std::path::Path) -> Option<PathBuf> {
    let binaries = exe.parent()?;
    let contents = binaries.parent()?;
    if binaries.file_name()?.to_str()? != "MacOS"
        || contents.file_name()?.to_str()? != "Contents"
        || contents.parent()?.extension()?.to_str()? != "app"
    {
        return None;
    }
    Some(contents.join("Resources"))
}

pub fn initialize_app_data(resources: &std::path::Path) -> Result<PathBuf> {
    let home = std::env::var_os("HOME").filter(|home| !home.is_empty()).ok_or("HOME is missing")?;
    let root = PathBuf::from(home).join("Library/Application Support/Orvyn");
    fs::create_dir_all(&root).map_err(err)?;
    fs::set_permissions(&root, fs::Permissions::from_mode(0o700)).map_err(err)?;
    let _lock = core::Lock::acquire("Orvyn-macos-initialize")?;
    for name in ["settings.json", "custom-models.json", "model-catalog.json"] {
        let destination = root.join("config").join(name);
        if !destination.exists() {
            let value = core::read_json(&resources.join("config").join(name))?;
            core::atomic(&destination, &value)?;
        }
    }
    Ok(root)
}

pub fn error(text: &str) {
    if std::env::var_os("CI").is_some() { return; }
    let _ = core::hidden("/usr/bin/osascript")
        .args(["-e", "on run argv", "-e", "display alert \"Orvyn could not start\" message (item 1 of argv) as critical", "-e", "end run", "--", text])
        .output();
}

pub fn run(root: PathBuf) -> Result<()> {
    crate::web::run(root, false)
}

pub fn smoke_test(root: PathBuf) -> Result<()> {
    crate::web::run(root, true)
}

pub fn pick_model_file() -> Option<PathBuf> {
    let output = core::hidden("/usr/bin/osascript")
        .args(["-e", "POSIX path of (choose file with prompt \"Select a GGUF model or projector\")"])
        .output().ok()?;
    if !output.status.success() { return None; }
    let path = String::from_utf8(output.stdout).ok()?;
    let path = PathBuf::from(path.trim_end_matches(['\r', '\n']));
    path.extension().is_some_and(|ext| ext.eq_ignore_ascii_case("gguf")).then_some(path)
}
