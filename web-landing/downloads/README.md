# Public desktop download

New free releases use GitHub Releases (D-022). Upload the notarized versioned
DMG plus byte-identical `MacDictate_Latest.dmg` alias, update registry and
`latest-desktop.json`, then run `scripts/verify_release_governance.sh --online`.

No DMG is committed to git or GitHub Pages. `publicUrl` points to the GitHub
latest-release asset; `publicPath` is retained as a legacy logical field.
The retired server and its old website alias are not a dependency of this channel.

## Windows desktop

`latest-windows.json` is a separate schema1Windows metadata document: version, min build19041, sourceSHA/finalCI, installer/portable aliases and exact SHA256, unsigned status and physical acceptance limit. Never replace the legacy macOS schema1manifest with a cross-platform incompatible shape. Both platform aliases must exist on the same complete GitHub release before making it latest.
