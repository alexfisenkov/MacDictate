#!/usr/bin/env python3
import argparse
import os
import shutil
import sys
from pathlib import Path

import bundle_llama_runtime as macho

DEFAULT_SEARCH_DIRS = [
    "/opt/homebrew/opt/whisper-cpp/lib",
    "/opt/homebrew/opt/ggml/lib",
    "/opt/homebrew/opt/libomp/lib",
    "/opt/homebrew/lib",
    "/usr/local/opt/whisper-cpp/lib",
    "/usr/local/opt/ggml/lib",
    "/usr/local/opt/libomp/lib",
    "/usr/local/lib",
]
RUNTIME_CANDIDATES = [
    "/opt/homebrew/bin/whisper-cli",
    "/usr/local/bin/whisper-cli",
]
GGML_BACKEND_DIRS = [
    "/opt/homebrew/opt/ggml/libexec",
    "/usr/local/opt/ggml/libexec",
]


def find_runtime(explicit_runtime):
    candidates = [explicit_runtime] if explicit_runtime else RUNTIME_CANDIDATES
    for candidate in candidates:
        if candidate and os.path.isfile(candidate) and os.access(candidate, os.X_OK):
            return Path(candidate).resolve()
    return None


def find_ggml_backend_dir(explicit_backend_dir):
    candidates = [explicit_backend_dir] if explicit_backend_dir else GGML_BACKEND_DIRS
    for candidate in candidates:
        if candidate and Path(candidate).is_dir():
            return Path(candidate).resolve()
    return None


def ensure_rpath(path, rpath):
    if rpath not in macho.macho_rpaths(path):
        macho.run(["install_name_tool", "-add_rpath", rpath, str(path)])


def copy_dependency(source, lib_dir):
    dest = lib_dir / Path(source).name
    if not dest.exists():
        shutil.copy2(source, dest)
        dest.chmod(dest.stat().st_mode | 0o644)
    macho.patch_macho(dest, is_library=True)
    return dest


def copy_ggml_backends(backend_dir, resources_dir, search_dirs):
    if backend_dir is None:
        return []

    lib_dir = resources_dir / "lib"
    bundled_backend_dir = resources_dir / "libexec" / "ggml"
    lib_dir.mkdir(parents=True, exist_ok=True)
    bundled_backend_dir.mkdir(parents=True, exist_ok=True)

    copied_backends = []
    for backend_source in sorted(backend_dir.glob("libggml-*.so")):
        backend_dest = bundled_backend_dir / backend_source.name
        shutil.copy2(backend_source, backend_dest)
        backend_dest.chmod(backend_dest.stat().st_mode | 0o755)

        dependencies = macho.collect_dependencies(backend_source, search_dirs)
        for dependency_source in dependencies:
            copy_dependency(dependency_source, lib_dir)

        macho.patch_macho(backend_dest, is_library=True)
        ensure_rpath(backend_dest, "@loader_path/../../lib")
        copied_backends.append(backend_dest)

    return copied_backends


def main():
    parser = argparse.ArgumentParser(description="Bundle whisper.cpp runtime into MacDictate.app resources.")
    parser.add_argument("--resources", required=True, help="Path to MacDictate.app/Contents/Resources")
    parser.add_argument("--runtime", default="", help="Optional path to whisper-cli")
    parser.add_argument("--ggml-backends", default="", help="Optional path to ggml libexec backend directory")
    args = parser.parse_args()

    resources_dir = Path(args.resources)
    runtime_path = find_runtime(args.runtime)
    if runtime_path is None:
        print("whisper-cli runtime not found. Install whisper.cpp or set MACDICTATE_WHISPER_RUNTIME_PATH.", file=sys.stderr)
        return 1

    search_dirs = [str(Path(path).resolve()) for path in DEFAULT_SEARCH_DIRS if Path(path).exists()]
    runtime_dest, libraries = macho.copy_runtime(runtime_path, resources_dir, search_dirs)
    backend_dir = find_ggml_backend_dir(args.ggml_backends)
    backends = copy_ggml_backends(backend_dir, resources_dir, search_dirs)

    print(f"Bundled whisper runtime: {runtime_dest}")
    for lib in sorted(libraries):
        print(f"Bundled whisper dependency: {lib}")
    for backend in sorted(backends):
        print(f"Bundled ggml backend: {backend}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
