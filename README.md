# Orvyn

A portable Windows AI app with Chat and the Opex Work coding workspace. The default model is **Orvyn 1**, a local assistant profile based on Llama 3.2 1B Instruct Q4_K_M. English is the default response language; choose another response language in Settings.

## Run the app

On the development USB, run `START.bat`. For the portable distribution, open `dist/Orvyn-portable/Orvyn.exe` or its `START.bat`.

Keep the portable folder together. The model and inference runtime are included alongside the executable; they are not embedded inside the executable. No model download is required for that package. Windows WebView2 must be installed. The application derives its root from its executable location, so the USB drive letter may change.

## Features

- Chat with the included Orvyn 1 model or connect an OpenAI-compatible API, including OpenRouter.
- Opex Work: persistent tasks, project browsing, a task timeline, reviewed changes, backups, live terminal output, and a stop button.
- Plan mode for discussion without executing model actions. Work pauses after eight automatic steps.
- Settings, startup diagnostics, training reports, document tools, and a working-copy editor.

Opex is an independent coding workspace, not a complete implementation of Codex. Its answers depend on the chosen model. File operations are limited to a project on the USB. Approved PowerShell commands use the Windows account permissions and may access locations outside that project. Commands have a 60-second limit.

Orvyn 1 is a profile on an existing base model, not a newly trained foundation model. Experimental Orvyn training candidates are not activated automatically.

## Source layout

- `apps/web-ui`: React / TypeScript / CSS interface.
- `apps/manager`: Rust desktop host and local APIs.
- `scripts`: USB environment, build, test, and packaging commands.
- `config/*.example.json`: clean configuration templates, containing only Orvyn 1.
- `tests`: source tests; generated fixtures and screenshots are excluded from Git.
- `tools/training`: optional CPU training utilities. Training data and outputs stay local.

The repository excludes models, executables, runtimes, toolchains, caches, conversations, WebView profiles, API credentials, personal configuration, logs, and backups. It is a source repository, not a model-weight distribution.

## Build on Windows

Start from the USB project root:

```powershell
.\scripts\initialize-config.ps1
. .\scripts\usb-environment.ps1
Push-Location apps/web-ui
npm ci
Pop-Location
.\scripts\build-ui.ps1
.\scripts\build-desktop.ps1
.\scripts\deploy-desktop.ps1
.\scripts\package-portable.ps1
```

Use the existing Rust / Node toolchains. The desktop build expects the USB LLVM/MinGW tools at the path specified in `scripts/build-desktop.ps1`; that script performs an offline Cargo build and therefore needs its USB dependency cache prepared first. `scripts/prepare-cargo-cache.ps1` documents that step. No project installation under AppData or Program Files is needed.

Before packaging, supply the existing llamafile runtime at `runtime/llamafile/llamafile-0.10.6.exe` and the base model at `models/desktop-active/llama32-1b.gguf`, with its verification metadata. The source URL and expected SHA-256 are in `config/custom-models.example.json`. Keep the original model and runtime licenses with any redistribution; they are not replaced by the app name.

## Validation

```powershell
. .\scripts\usb-environment.ps1
node apps/web-ui/node_modules/typescript/bin/tsc --project apps/web-ui/tsconfig.json --noEmit --incremental false
node tests/workspace-ui.mjs
node tests/opex-work-ui.mjs
.\scripts\test-workspace-api.ps1
.\scripts\test-manager.ps1
```

Browser integration tests use test model responses. Native tests exercise real local file operations and PowerShell in isolated folders under `tests`.

## GitHub Desktop

Open the USB root as the local repository in GitHub Desktop. Publish it as `orvyn` and keep **Keep this code private** selected unless you intend to make the source public. Review the source-only file list before publishing. Never force-add ignored credentials, conversations, or model files.