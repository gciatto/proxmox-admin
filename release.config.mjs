import config from 'semantic-release-preconfigured-conventional-commits' with {type: 'json'};

// The image is pushed in `prepare`, i.e. before @semantic-release/git commits and tags:
// if the push fails, no release commit, tag, or GitHub release is produced.
config.plugins.push(
    ["@semantic-release/exec", {
        "verifyConditionsCmd": "docker buildx version",
        "prepareCmd": "sed -i -E 's/^version = \".*\"/version = \"${nextRelease.version}\"/' pyproject.toml"
            + " && bash scripts/release-image.sh ${nextRelease.version}",
    }],
    "@semantic-release/github",
    ["@semantic-release/git", {
        "assets": ["CHANGELOG.md", "pyproject.toml"],
        "message": "chore(release): ${nextRelease.version} [skip ci]\n\n${nextRelease.notes}"
    }]
);

export default config;
