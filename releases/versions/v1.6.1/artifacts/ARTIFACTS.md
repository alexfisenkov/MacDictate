# Windows v1.6.1 candidate artifacts

Exact checked source: `56b45301bc0e98c12f4823e5039152a3c3dd5229`; final CI: `40747430459`. Status: Windows-only public release at `2026-10-28T19:07:43Z`; public API size/digest read-back4/4 PASS; final Pages publication/read-back pending.

- `MacDictate_Windows_v1.6.1_x64.exe`: 54351051 bytes; SHA-256 `fe85fd784649f057d16a115392b3c09cb7ceaf42e8f59beefc05d8149b3307e9`.
- `MacDictate_Windows_v1.6.1_x64.zip`: 77339968 bytes; SHA-256 `55eedeed0bda8e91dc807cab00fefc9041e5c3d1151984508107e1e287c6365d`.
- `windows-build-manifest.json` and `WINDOWS-SHA256SUMS`: exact final workflow files, retained without reserialization.
- `MacDictate_Windows_Latest_x64.exe` / `.zip`: byte-identical local copies only; do not publish these aliases for this Windows-only channel.
- `evidence/`: all 7 actual JSON and 49 PNG files from the final artifact. Synthetic test inputs only; raw audio/model and personal data are excluded. One populated installed PNG referenced in JSON is absent; no visual check of that missing file is claimed.
- `RELEASE_NOTES.md`: exact published GitHub release body with first steps and test boundaries; stored as release body, not an uploaded asset.
- `publication-pending.json`: completed publication handoff with actual release ID/timestamp/URL and state `published_windows_channel_promoted_site_pending`; original filename retained.

`SHA256SUMS` covers the two packages, local aliases and exact source manifest/checksum files. `WINDOWS-SHA256SUMS` deliberately covers only the two public versioned packages and is the uploaded public checksum file. The generic `SHA256SUMS` is local-only and must not be linked as a release asset. Binaries/evidence/release body/pending metadata are git-ignored. `RELEASE.md` records verification bounds and open acceptance work.
