#!/usr/bin/env bash
set -euo pipefail

# Source checks shared by CI and the Git hooks; --test also runs the unit tests.
# Run through uv, which provides the dev dependencies: uv run bash scripts/check.sh [--test]
cd "$(dirname "${BASH_SOURCE[0]}")/.."
for script in admin.sh scripts/*.sh; do
    bash -n "$script"
done
sh -n docker/entrypoint.sh
python3 scripts/check-yaml.py
if [[ "${1:-}" == --test ]]; then
    python3 -m unittest discover -s tests -v
fi
