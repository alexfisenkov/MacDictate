#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

TEST_SWIFT="$TMP_DIR/main.swift"
TEST_BIN="$TMP_DIR/test_llama_runtime_locator"

cat > "$TEST_SWIFT" <<'SWIFT'
import Foundation

func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("Assertion failed: \(message)\n", stderr)
        exit(1)
    }
}

let root = URL(fileURLWithPath: CommandLine.arguments[1])
let resources = root.appendingPathComponent("Resources")
let bin = resources.appendingPathComponent("bin")
let fallbackDir = root.appendingPathComponent("Fallback")
try FileManager.default.createDirectory(at: bin, withIntermediateDirectories: true)
try FileManager.default.createDirectory(at: fallbackDir, withIntermediateDirectories: true)

func touchExecutable(_ url: URL, executable: Bool = true) {
    FileManager.default.createFile(atPath: url.path, contents: Data("#!/bin/sh\n".utf8))
    let permissions: Int16 = executable ? 0o755 : 0o644
    try? FileManager.default.setAttributes([.posixPermissions: permissions], ofItemAtPath: url.path)
}

let bundledCompletion = bin.appendingPathComponent("llama-completion")
let bundledCli = bin.appendingPathComponent("llama-cli")
let fallbackCompletion = fallbackDir.appendingPathComponent("llama-completion")
let fallbackCli = fallbackDir.appendingPathComponent("llama-cli")

touchExecutable(fallbackCompletion)
expect(
    LlamaRuntimeLocator.findRuntimePath(resourcePath: resources.path, fallbackPaths: [fallbackCompletion.path]) == fallbackCompletion.path,
    "expected fallback completion when bundled runtime is missing"
)

touchExecutable(bundledCli)
expect(
    LlamaRuntimeLocator.findRuntimePath(resourcePath: resources.path, fallbackPaths: [fallbackCompletion.path]) == bundledCli.path,
    "expected bundled llama-cli before fallback"
)

touchExecutable(bundledCompletion, executable: false)
expect(
    LlamaRuntimeLocator.findRuntimePath(resourcePath: resources.path, fallbackPaths: [fallbackCompletion.path]) == bundledCli.path,
    "expected non-executable bundled completion to be ignored"
)

try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: bundledCompletion.path)
expect(
    LlamaRuntimeLocator.findRuntimePath(resourcePath: resources.path, fallbackPaths: [fallbackCompletion.path]) == bundledCompletion.path,
    "expected bundled llama-completion to be preferred"
)

try FileManager.default.removeItem(at: bundledCompletion)
try FileManager.default.removeItem(at: bundledCli)
try FileManager.default.removeItem(at: fallbackCompletion)
touchExecutable(fallbackCli)
expect(
    LlamaRuntimeLocator.findRuntimePath(resourcePath: resources.path, fallbackPaths: [fallbackCli.path]) == fallbackCli.path,
    "expected fallback llama-cli"
)

try FileManager.default.removeItem(at: fallbackCli)
expect(
    LlamaRuntimeLocator.findRuntimePath(resourcePath: resources.path, fallbackPaths: []) == nil,
    "expected nil when no runtime is available"
)

print("LlamaRuntimeLocator test passed.")
SWIFT

swiftc \
    "$ROOT_DIR/src/TextImprovement/LlamaRuntimeLocator.swift" \
    "$TEST_SWIFT" \
    -o "$TEST_BIN"

"$TEST_BIN" "$TMP_DIR"
