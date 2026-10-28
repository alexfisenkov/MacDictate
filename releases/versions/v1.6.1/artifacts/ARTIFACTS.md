# Windows v1.6.1 candidate artifacts

Exact checked source: `56b45301bc0e98c12f4823e5039152a3c3dd5229`; final CI: `40747430459`. Status: local candidate, not published.

- `MacDictate_Windows_v1.6.1_x64.exe`: 54351051 bytes; SHA-256 `fe85fd784649f057d16a115392b3c09cb7ceaf42e8f59beefc05d8149b3307e9`.
- `MacDictate_Windows_v1.6.1_x64.zip`: 77339968 bytes; SHA-256 `55eedeed0bda8e91dc807cab00fefc9041e5c3d1151984508107e1e287c6365d`.
- `windows-build-manifest.json` and `WINDOWS-SHA256SUMS`: exact final workflow files, retained without reserialization.
- `MacDictate_Windows_Latest_x64.exe` / `.zip`: byte-identical local copies only; do not publish these aliases for this Windows-only channel.
- `evidence/`: all 7 actual JSON and 49 PNG files from the final artifact. Synthetic test inputs only; raw audio/model and personal data are excluded. One populated installed PNG referenced in JSON is absent; no visual check of that missing file is claimed.
- `RELEASE_NOTES.md`: ready GitHub release body with first steps and test boundaries; not proof of publication.
- `publication-pending.json`: expected assets and null publication identity; replace only with actual published read-back, then promote Windows pointers under D-025.

`SHA256SUMS` covers the two packages, local aliases and exact source manifest/checksum files. `WINDOWS-SHA256SUMS` deliberately covers only the two public versioned packages. Binaries/evidence/release body/pending metadata are git-ignored. `RELEASE.md` records verification bounds and open acceptance work.
