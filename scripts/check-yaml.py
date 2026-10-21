"""Validate checked-in YAML, including GitHub's `on` mapping key."""

from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[1]
WORKFLOWS = ROOT / ".github" / "workflows"

paths = sorted(WORKFLOWS.glob("*.yml"))
paths += sorted((ROOT / "ansible").rglob("*.yml"))
paths += sorted((ROOT / "ansible").rglob("*.yml.example"))
paths += sorted(ROOT.glob("compose*.yaml"))
if not paths:
    raise SystemExit("No YAML configuration files found")

for path in paths:
    # BaseLoader avoids YAML 1.1 interpreting the GitHub Actions 'on' key as True.
    parsed = yaml.load(path.read_text(encoding="utf-8"), Loader=yaml.BaseLoader)
    if not isinstance(parsed, (dict, list)):
        raise SystemExit(f"Expected a mapping or playbook list at {path}")
    if path.parent == WORKFLOWS and ("on" not in parsed or "jobs" not in parsed):
        raise SystemExit(f"Workflow missing event triggers or jobs: {path}")
    print(f"OK {path.relative_to(ROOT)}")

ci = yaml.load((WORKFLOWS / "ci.yml").read_text(), Loader=yaml.BaseLoader)
release = yaml.load((WORKFLOWS / "release.yml").read_text(), Loader=yaml.BaseLoader)
assert "workflow_call" in ci["on"], "CI must be callable as a release prerequisite"
assert "pull_request" in ci["on"], "CI must run for pull requests"
assert release["jobs"]["publish"]["needs"] == "verify", "Publishing must depend on tests"
assert release["jobs"]["verify"]["uses"] == "./.github/workflows/ci.yml"
