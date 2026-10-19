# Web Download Alias

`MacDictate_Latest.dmg` is the public website alias for the current desktop stable release.

The binary DMG is intentionally not tracked in git. On every public desktop release:

1. upload the notarized DMG to the GitHub Release;
2. upload the same DMG bytes to the website as `/downloads/MacDictate_Latest.dmg`;
3. update `latest-desktop.json` from `releases/registry.json`;
4. run `scripts/verify_release_governance.sh --online`.

The website must never keep serving an older DMG after a new public release is approved.

## Free channel (D-022, 2026-10-19)

The old server is switched off. New releases use GitHub Releases for both
versioned DMG and `MacDictate_Latest.dmg` alias. No DMG is committed to git
or GitHub Pages. `latest-desktop.json.publicUrl` points to the GitHub asset.
