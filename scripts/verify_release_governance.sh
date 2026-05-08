#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REGISTRY="$ROOT_DIR/releases/registry.json"
ONLINE=0
STRICT_LOCAL_ARTIFACTS=0

for arg in "$@"; do
  case "$arg" in
    --online)
      ONLINE=1
      ;;
    --strict-local-artifacts)
      STRICT_LOCAL_ARTIFACTS=1
      ;;
    *)
      echo "Unknown argument: $arg" >&2
      exit 2
      ;;
  esac
done

python3 - "$ROOT_DIR" "$REGISTRY" "$ONLINE" "$STRICT_LOCAL_ARTIFACTS" <<'PY'
import hashlib
import json
import plistlib
import re
import subprocess
import sys
from pathlib import Path

root = Path(sys.argv[1])
registry_path = Path(sys.argv[2])
online = sys.argv[3] == "1"
strict_local_artifacts = sys.argv[4] == "1"
errors = []
warnings = []
VERSION_RE = re.compile(r"^v\d+\.\d+(?:\.\d+)?(?:-(?:local|working))?$")
ALLOWED_STATUSES = {
    "public_stable",
    "public_release",
    "local_only",
    "working_line",
    "checkpoint",
    "scratch",
}


def fail(message):
    errors.append(message)


def warn(message):
    warnings.append(message)


def rel(path):
    return str(path.relative_to(root))


def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def git(*args):
    result = subprocess.run(
        ["git", "-C", str(root), *args],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    return result


if not registry_path.exists():
    fail(f"Registry missing: {registry_path}")
else:
    with registry_path.open("r", encoding="utf-8") as fh:
        registry = json.load(fh)

    if registry.get("schemaVersion") != 1:
        fail("registry.schemaVersion must be 1")

    governance = root / registry.get("governanceDocument", "")
    if not governance.exists():
        fail(f"Governance document missing: {rel(governance)}")

    versions = registry.get("versions", [])
    seen_versions = set()
    stable_versions = []
    working_lines = []
    versions_root = root / "releases" / "versions"

    for item in versions:
        version = item.get("version")
        if not version:
            fail("Version entry without version")
            continue
        if not VERSION_RE.fullmatch(version):
            fail(
                f"{version}: version name does not match allowed release format "
                "(examples: v1.4, v1.4.2, v1.4.1-local, v1.5.0-working)"
            )
        if version in seen_versions:
            fail(f"Duplicate version entry: {version}")
        seen_versions.add(version)

        status = item.get("status")
        if status not in ALLOWED_STATUSES:
            fail(f"{version}: unknown status: {status}")
        if status == "working_line" and not version.endswith("-working"):
            fail(f"{version}: working_line versions must use the -working suffix")
        if status in {"public_stable", "public_release"} and (
            version.endswith("-local") or version.endswith("-working")
        ):
            fail(f"{version}: public releases must not use -local or -working suffixes")

        if status == "public_stable":
            stable_versions.append(version)
        if status == "working_line":
            working_lines.append(version)

        local = item.get("local", {})
        release_dir_value = local.get("releaseDir")
        if not release_dir_value:
            fail(f"{version}: local.releaseDir is required")
            release_dir = versions_root / version
        else:
            release_dir = root / release_dir_value
            try:
                release_dir_relative = release_dir.relative_to(versions_root)
            except ValueError:
                fail(f"{version}: local.releaseDir must be under releases/versions/")
            else:
                if len(release_dir_relative.parts) != 1:
                    fail(f"{version}: local.releaseDir must point to exactly one version folder")
                elif release_dir_relative.name != version:
                    fail(
                        f"{version}: local.releaseDir folder name must equal version "
                        f"(got {release_dir_relative.name})"
                    )

        release_md = release_dir / "RELEASE.md"
        if not release_dir.exists():
            fail(f"{version}: release directory missing: {rel(release_dir)}")
        if not release_md.exists():
            fail(f"{version}: RELEASE.md missing: {rel(release_md)}")
        else:
            release_text = release_md.read_text(encoding="utf-8")
            if version not in release_text:
                fail(f"{version}: RELEASE.md does not mention the version")
            if f"Status: `{status}`" not in release_text:
                fail(f"{version}: RELEASE.md does not contain Status: `{status}`")

        artifacts_dir = release_dir / "artifacts"
        artifacts_md = artifacts_dir / "ARTIFACTS.md"
        sums = artifacts_dir / "SHA256SUMS"
        if not artifacts_md.exists():
            fail(f"{version}: ARTIFACTS.md missing: {rel(artifacts_md)}")
        if not sums.exists():
            fail(f"{version}: SHA256SUMS missing: {rel(sums)}")

        artifact_path = local.get("artifactPath")
        expected_hash = local.get("localArtifactSha256")
        if artifact_path:
            artifact = root / artifact_path
            if not artifact.exists():
                message = (
                    f"{version}: local artifact not present in checkout: {artifact_path}. "
                    "This is allowed for git-ignored binary artifacts; run with "
                    "--strict-local-artifacts to require local files."
                )
                if strict_local_artifacts:
                    fail(message)
                else:
                    warn(message)
            elif expected_hash:
                actual_hash = sha256(artifact)
                if actual_hash != expected_hash:
                    fail(
                        f"{version}: artifact sha256 mismatch for {artifact_path}: "
                        f"expected {expected_hash}, got {actual_hash}"
                    )

        build_log_path = local.get("buildLogPath")
        if build_log_path and not (root / build_log_path).exists():
            message = (
                f"{version}: local build log not present in checkout: {build_log_path}. "
                "This is allowed for git-ignored local build logs; run with "
                "--strict-local-artifacts to require local files."
            )
            if strict_local_artifacts:
                fail(message)
            else:
                warn(message)

        tag = item.get("git", {}).get("localTag")
        if item.get("git", {}).get("tagRequiredLocally"):
            if not tag:
                fail(f"{version}: local tag required but localTag is empty")
            else:
                result = git("rev-parse", "--verify", f"refs/tags/{tag}")
                if result.returncode != 0:
                    fail(f"{version}: required local tag missing: {tag}")

        github = item.get("github", {})
        if status in {"public_release", "public_stable"}:
            if not github.get("releaseUrl"):
                fail(f"{version}: public release missing github.releaseUrl")
            if not github.get("assetName"):
                fail(f"{version}: public release missing github.assetName")
            if github.get("releaseUrl"):
                release_tag = github["releaseUrl"].rstrip("/").split("/")[-1]
                if release_tag != version:
                    fail(
                        f"{version}: github.releaseUrl tag must equal version "
                        f"(got {release_tag})"
                    )

    if len(stable_versions) != 1:
        fail(f"Expected exactly one public_stable version, found {stable_versions}")

    if not working_lines:
        fail("Expected at least one working_line entry")

    current = registry.get("current", {})
    if current.get("publicStable") and current.get("publicStable") not in stable_versions:
        fail(
            "registry.current.publicStable must point to the only public_stable version "
            f"(got {current.get('publicStable')})"
        )
    if current.get("workingLine") and current.get("workingLine") not in working_lines:
        fail(
            "registry.current.workingLine must point to a working_line version "
            f"(got {current.get('workingLine')})"
        )

    if not versions_root.exists():
        fail("releases/versions directory missing")
    else:
        actual_version_dirs = {
            path.name for path in versions_root.iterdir() if path.is_dir()
        }
        for folder_name in sorted(actual_version_dirs):
            if not VERSION_RE.fullmatch(folder_name):
                fail(
                    f"releases/versions/{folder_name}: folder name does not match "
                    "allowed release format"
                )
            if folder_name not in seen_versions:
                fail(
                    f"releases/versions/{folder_name}: version folder has no registry entry"
                )
        for version in sorted(seen_versions):
            if version not in actual_version_dirs:
                fail(
                    f"{version}: registry entry has no matching releases/versions/{version} folder"
                )

    root_artifacts = sorted(
        [
            path.name
            for path in root.iterdir()
            if path.is_file()
            and (
                path.suffix == ".dmg"
                or path.name.startswith("build_log")
                or (path.name.startswith("build_v") and path.name.endswith("_log.txt"))
                or path.name == "dev_null.txt"
            )
        ]
    )
    if root_artifacts:
        fail(
            "Root artifact clutter found; move files into releases/versions/*/artifacts "
            f"or releases/archive/*/artifacts: {', '.join(root_artifacts)}"
        )

    build_script = root / "build.sh"
    if build_script.exists():
        build_text = build_script.read_text(encoding="utf-8")
        if 'DMG_PATH="$PROJECT_DIR/$DMG_NAME"' in build_text:
            fail("build.sh writes DMG to project root; expected build/artifacts output")

    info_plist = root / "assets" / "Info.plist"
    if not info_plist.exists():
        fail("assets/Info.plist missing")
    else:
        with info_plist.open("rb") as fh:
            plist = plistlib.load(fh)
        current = registry.get("current", {})
        short_version = plist.get("CFBundleShortVersionString")
        build = plist.get("CFBundleVersion")
        if short_version != current.get("bundleShortVersion"):
            fail(
                "Info.plist CFBundleShortVersionString "
                f"({short_version}) does not match registry current.bundleShortVersion "
                f"({current.get('bundleShortVersion')})"
            )
        if build != current.get("bundleVersion"):
            fail(
                "Info.plist CFBundleVersion "
                f"({build}) does not match registry current.bundleVersion "
                f"({current.get('bundleVersion')})"
            )

    current_branch = git("branch", "--show-current")
    if current_branch.returncode == 0:
        branch = current_branch.stdout.strip()
        expected_branch = registry.get("current", {}).get("developmentBranch")
        if expected_branch and branch != expected_branch:
            warn(f"Current branch is {branch}; registry developmentBranch is {expected_branch}")

    if online:
        for item in versions:
            github = item.get("github", {})
            release_url = github.get("releaseUrl")
            asset_name = github.get("assetName")
            if not release_url or not asset_name:
                continue
            tag = release_url.rstrip("/").split("/")[-1]
            api_url = f"https://api.github.com/repos/alexfisenkov/MacDictate/releases/tags/{tag}"
            try:
                result = subprocess.run(
                    ["curl", "-fsSL", "--max-time", "15", api_url],
                    stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE,
                    text=True,
                )
                if result.returncode != 0:
                    raise RuntimeError(result.stderr.strip() or "curl failed")
                data = json.loads(result.stdout)
            except Exception as exc:
                fail(f"{item.get('version')}: GitHub release lookup failed: {exc}")
                continue
            assets = {asset.get("name"): asset for asset in data.get("assets", [])}
            if asset_name not in assets:
                fail(f"{item.get('version')}: GitHub asset missing: {asset_name}")
            digest = assets.get(asset_name, {}).get("digest")
            expected_digest = github.get("githubAssetSha256")
            if expected_digest and digest and digest != f"sha256:{expected_digest}":
                fail(
                    f"{item.get('version')}: GitHub asset digest mismatch: "
                    f"expected sha256:{expected_digest}, got {digest}"
                )

for message in warnings:
    print(f"WARN: {message}")

if errors:
    for message in errors:
        print(f"ERROR: {message}")
    sys.exit(1)

print("Release governance verification passed.")
PY
