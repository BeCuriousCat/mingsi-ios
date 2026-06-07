#!/usr/bin/env bash
set -euo pipefail
framework_root="/Users/chenzewei/Documents/codex/projects/codex-claude-delegation-framework"
project_root="/Users/chenzewei/Documents/codex/projects/mingsi-ios"
exec python3 "$framework_root/bin/delegation_experience.py" emit --project-root "$project_root" "$@"
