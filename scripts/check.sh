#!/usr/bin/env bash
set -euo pipefail

# Source checks shared by CI and the Git hooks; --test also runs the unit tests.
cd "$(dirname "${BASH_SOURCE[0]}")/.."
for script in admin.sh scripts/*.sh; do
    bash -n "$script"
done
sh -n docker/entrypoint.sh
if python3 -c 'import yaml' 2>/dev/null; then
    python3 scripts/check-yaml.py
else
    echo "YAML checks skipped: python3 -m pip install 'PyYAML>=6,<7' (CI always runs them)" >&2
fi
if [[ "${1:-}" == --test ]]; then
    python3 -m unittest discover -s tests -v
fi
