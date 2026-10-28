# Windows v1.6.1-working

Status: `working_line`

Windows-only source candidate; no new package, CI run, tag, public release or Pages publication is claimed. Windows publicStable remains v1.6.0. macOS stays1.6.0/build14; global GitHub latest remains v1.6.0.

Changes: visible RU/EN first-run window, explicit model/microphone/hotkey setup and record/stop/copy flow; EXE primary download and ZIP alternative; pinned Windows stable channel; one final manual CI with isolated UI/real bundled ASR on synthetic speech, normal installed fresh-profile launch and exact payload/source/hash checks.

Canonical Windows candidate version: `windows/src/MacDictate.Windows/MacDictate.Windows.csproj`. Build/installer derive asset names via `windows/scripts/release-info.ps1`. `current.windows` defines its independent stable/working lines; legacy `current.publicStable` remains the Mac channel.

Evidence at preparation: portable app checks had46PASS and cross-build0warnings before delivery changes (root-confirmed T01). T02 local verification after concurrent app repair:54portable checks PASS, Windows cross-build0warnings/errors, PowerShell parsing/canonical names/no-overwrite guard PASS, Windows delivery/root governance PASS, RU/EN JS syntax/key parity PASS. The checker also rejects global-latest URLs, wrong sourceSHA and same-size artifact tampering. No native runtime PASS is implied by these local checks.

Pending: final independent review, one manual CI exact sourceSHA, real ASR on synthetic fixture, installer/normal UI, synthetic layout125/150% and PNG read-back. Physical Windows10/11 mic/Alt/editor and native monitor125/150% are NOT_RUN. Unsigned packages remain explicitly unsigned.

Publication sequence: `docs/7_Release_Governance.md` Windows-only hotfix section. Create v1.6.1 with `make_latest=false`, upload only actual checked Windows assets and manifests/checksums, read back public digests, then promote Windows ledger/manifest/HTML fallback links to exact tag. Preserve prior assets/models and the global Mac latest.

Known source-review gate: the long setup flow may leave result/Copy below the visible viewport. `resultVisibleBeforeTestScroll` is captured before diagnostic scrolling; final acceptance requires true, including synthetic layout125/150%. F1 production repair/verification is pending; scrolled screenshots are not used to claim automatic visibility.


## Preparation history closed — 2026-10-29

The paragraphs above describe the source-preparation stage, not current hosted acceptance. The checked final source56b45301/run40747430459 and exact packages now have a separate canonical `v1.6.1` entry, published with status `public_release` at2026-10-28T19:07:43Z; see `releases/versions/v1.6.1/RELEASE.md`. The working pointer and null build/publication fields remain preparation history. Do not infer publication or physical Windows10/11/native-DPI acceptance from hosted G4 PASS.
