# Orvyn

A portable Windows AI app with Chat and the Opex Work coding workspace. The default model is **Orvyn 1**, a local assistant profile based on Llama 3.2 1B Instruct Q4_K_M. English is the default response language; choose another response language in Settings.

## Run the app

On the development USB, run `START.bat`. For the portable distribution, open `dist/Orvyn-portable/Orvyn.exe` or its `START.bat`.

For the installation wizard, run `dist/Orvyn-Setup-0.7.0.exe`. It includes Orvyn 1, uses English, and defaults to an Orvyn folder beside the installer. Shortcuts and Windows installed-apps registration are optional. Updates preserve existing configuration and conversations. The included uninstaller keeps settings, models, conversations and backups.

Keep the portable folder together. The model and inference runtime are included alongside the executable; they are not embedded inside the executable. No model download is required for that package. Windows WebView2 must be installed. The application derives its root from its executable location, so the USB drive letter may change.

## Features

- Chat with the included Orvyn 1 model or connect an OpenAI-compatible API, including OpenRouter.
- AI library: the library searches the Hugging Face API for GGUF models, sorts them into the Chat, Code, Reasoning and Vision categories, and downloads the chosen model to the USB with SHA-256 verification through the existing download queue.
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
.\scripts\prepare-cargo-cache.ps1
.\scripts\build-desktop.ps1
.\scripts\deploy-desktop.ps1
.\scripts\package-portable.ps1
.\scripts\build-installer.ps1
```

Use the existing Rust / Node toolchains. The desktop scripts detect the installed Rust host. MSVC Rust uses an existing Visual Studio C++ workload and Windows SDK; GNU Rust uses the project-local LLVM/MinGW tools. Run `scripts/prepare-cargo-cache.ps1` once with internet access to populate the project-local registry index and locked dependency archives. Builds and native tests then run with `--locked --offline`. `scripts/rust-environment.ps1` initializes compiler paths for the current process only. No project installation under AppData or Program Files is needed.

Before packaging, supply the existing llamafile runtime at `runtime/llamafile/llamafile-0.10.6.exe` and the base model at `models/desktop-active/llama32-1b.gguf`, with its verification metadata. The source URL and expected SHA-256 are in `config/custom-models.example.json`. Keep the original model and runtime licenses with any redistribution; they are not replaced by the app name.

The installer build uses an existing [Inno Setup compiler](https://jrsoftware.org/ishelp/topic_compilercmdline.htm); use `-Compiler` if it is not found automatically. Build caches and temporary files stay on the USB. Installer source and bundled notices are in `apps/manager/packaging`. Installer executables and checksums stay under `dist` and are excluded from Git. Built with Llama.

## Validation

```powershell
. .\scripts\usb-environment.ps1
node apps/web-ui/node_modules/typescript/bin/tsc --project apps/web-ui/tsconfig.json --noEmit --incremental false
node tests/workspace-ui.mjs
node tests/opex-work-ui.mjs
.\scripts\test-workspace-api.ps1
.\scripts\test-manager.ps1
.\scripts\test-installer.ps1
```

Browser integration tests use test model responses. Native tests exercise real local file operations and PowerShell in isolated folders under `tests`.

## GitHub Desktop

Open the USB root as the local repository in GitHub Desktop. Publish it as `orvyn` and keep **Keep this code private** selected unless you intend to make the source public. Review the source-only file list before publishing. Never force-add ignored credentials, conversations, or model files.

## 0.7.0 package variants

Build the standard installer with scripts/build-installer.ps1. Use -WithoutOrvyn1 for Orvyn-Setup-0.7.0-No-Orvyn-1.exe and a separate Orvyn-portable-No-Orvyn-1 staging folder. The latter contains no Orvyn 1 profile or model weights; connect an API or download a model to begin. Existing installations retain their user configuration and models. This packaging release reuses the existing desktop binary; it is not a new native application build.

## License

Orvyn application source and documentation are licensed under the [MIT License](LICENSE). Model weights, llamafile, and third-party dependencies retain their own licenses. Redistribution notices are under `apps/manager/packaging/licenses/`. The MIT license does not replace the Llama license or acceptable-use policy.

## Language

Application labels, messages, prompts, and documentation use English. Response language remains configurable. Existing saved preferences and conversations are preserved. Legacy internal preference values remain unchanged for compatibility. Intentional multilingual training and evaluation examples retain their original language.

## GitHub collaboration

See [GitHub Actions and issues](docs/GITHUB.md) for CI checks and issue forms, and the [improvement backlog](docs/ISSUE-BACKLOG.md) for ready-to-file issue drafts.
