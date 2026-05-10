#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

cat > "$TMP_DIR/main.swift" <<'SWIFT'
import Foundation

func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

let suiteName = "MacDictateLastDictationStoreTest-\(UUID().uuidString)"
guard let defaults = UserDefaults(suiteName: suiteName) else {
    fputs("FAIL: unable to create isolated UserDefaults suite\n", stderr)
    exit(1)
}
defaults.removePersistentDomain(forName: suiteName)

let store = LastDictationStore(userDefaults: defaults)
expect(store.latest() == nil, "new store should start empty")

store.save("")
store.save("   \n\t")
expect(store.latest() == nil, "empty or whitespace-only dictation should not replace latest text")

store.save("  первая сохранённая диктовка  ")
guard let saved = store.latest() else {
    fputs("FAIL: expected saved dictation\n", stderr)
    exit(1)
}
expect(saved.text == "первая сохранённая диктовка", "saved dictation should be trimmed")
expect(abs(saved.createdAt.timeIntervalSinceNow) < 5, "saved timestamp should be current")

let reloadedStore = LastDictationStore(userDefaults: defaults)
expect(reloadedStore.latest()?.text == "первая сохранённая диктовка", "latest text should persist")

reloadedStore.save("вторая диктовка")
expect(store.latest()?.text == "вторая диктовка", "latest text should be replaceable")

reloadedStore.clear()
expect(store.latest() == nil, "clear should remove saved dictation")

defaults.removePersistentDomain(forName: suiteName)
print("LastDictationStore test passed.")
SWIFT

swiftc \
    "$ROOT_DIR/src/Transcription/LastDictationStore.swift" \
    "$TMP_DIR/main.swift" \
    -o "$TMP_DIR/test_last_dictation_store"

"$TMP_DIR/test_last_dictation_store"
