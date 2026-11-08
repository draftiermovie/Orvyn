#!/bin/bash
# Initialize config/settings.json from the example when it is missing.
set -e
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [ -f config/settings.json ]; then
    echo "Configuration already exists: config/settings.json"
    exit 0
fi

mkdir -p config data logs backups models runtime
if [ -f config/settings.example.json ]; then
    cp config/settings.example.json config/settings.json
    echo "Configuration initialized from config/settings.example.json"
else
    cat > config/settings.json << 'EOF'
{
  "app": {
    "name": "Orvyn",
    "version": "0.8.0",
    "description": "Portable AI workspace"
  },
  "model_policy": {
    "idle_seconds": 1800,
    "max_loaded": 1,
    "start_on_launch": false,
    "default_model": ""
  },
  "paths": {
    "models": "models/desktop-active",
    "llamafile": "runtime/llamafile/llamafile",
    "data": "data",
    "backups": "backups",
    "logs": "logs/current",
    "web_ui": "apps/web-ui/dist"
  },
  "services": {}
}
EOF
    echo "Configuration initialized: config/settings.json"
fi
