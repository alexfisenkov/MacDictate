# Windows1.6.1 candidate artifacts

No artifact exists at this preparation stage. `SHA256SUMS` is intentionally empty. Do not invent bytes, hashes, source SHA or CI evidence.

After the single final manual workflow, retain the exact EXE/ZIP, `windows-build-manifest.json`, `WINDOWS-SHA256SUMS` and synthetic-only smoke JSON/PNG from `windows-x64-<full-source-sha>`. Validate with `python3 windows/scripts/check-delivery.py --build-manifest <directory>/windows-build-manifest.json --source-sha <checked-full-sha>` before any publication.

Audio WAV and model files are test inputs, not published artifacts. macOS DMG and all historical Windows files remain untouched.


Preparation-stage note above is historical. Final checked artifacts are retained under `releases/versions/v1.6.1/artifacts/`, registered as `local_only`; this working folder deliberately has no duplicate package set.
