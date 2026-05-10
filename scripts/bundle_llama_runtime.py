#!/usr/bin/env python3
import argparse
import os
import shutil
import subprocess
import sys
from pathlib import Path

SYSTEM_PREFIXES = ("/usr/lib/", "/System/Library/")
DEFAULT_SEARCH_DIRS = [
    "/opt/homebrew/opt/llama.cpp/lib",
    "/opt/homebrew/opt/ggml/lib",
    "/opt/homebrew/opt/openssl@3/lib",
    "/opt/homebrew/lib",
    "/usr/local/opt/llama.cpp/lib",
    "/usr/local/opt/ggml/lib",
    "/usr/local/opt/openssl@3/lib",
    "/usr/local/lib",
]
RUNTIME_CANDIDATES = [
    "/opt/homebrew/bin/llama-completion",
    "/usr/local/bin/llama-completion",
    "/opt/homebrew/bin/llama-cli",
    "/usr/local/bin/llama-cli",
]


def run(args):
    subprocess.run(args, check=True, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)


def output(args):
    return subprocess.check_output(args, text=True)


def is_system_dependency(path):
    return path.startswith(SYSTEM_PREFIXES)


def macho_dependencies(path):
    lines = output(["otool", "-L", str(path)]).splitlines()[1:]
    deps = []
    for line in lines:
        stripped = line.strip()
        if not stripped:
            continue
        deps.append(stripped.split(" ", 1)[0])
    return deps


def macho_rpaths(path):
    lines = output(["otool", "-l", str(path)]).splitlines()
    rpaths = []
    for index, line in enumerate(lines):
        if "cmd LC_RPATH" not in line:
            continue
        for candidate in lines[index + 1:index + 5]:
            stripped = candidate.strip()
            if stripped.startswith("path "):
                rpaths.append(stripped.split(" ", 2)[1])
                break
    return rpaths


def expand_loader_path(value, loader_dir):
    return value.replace("@loader_path", str(loader_dir))


def resolve_dependency(dep, loader_path, search_dirs):
    if is_system_dependency(dep):
        return None

    loader_dir = Path(loader_path).parent
    if dep.startswith("@loader_path/"):
        candidate = Path(expand_loader_path(dep, loader_dir)).resolve()
        if candidate.exists():
            return candidate

    if dep.startswith("@rpath/"):
        relative_name = dep[len("@rpath/"):]
        for rpath in macho_rpaths(loader_path):
            candidate = Path(expand_loader_path(rpath, loader_dir), relative_name).resolve()
            if candidate.exists():
                return candidate

    if dep.startswith("/"):
        candidate = Path(dep).resolve()
        if candidate.exists():
            return candidate

    basename = Path(dep).name
    for directory in search_dirs:
        candidate = Path(directory, basename).resolve()
        if candidate.exists():
            return candidate

    raise RuntimeError(f"Could not resolve dependency '{dep}' for {loader_path}")


def find_runtime(explicit_runtime):
    candidates = [explicit_runtime] if explicit_runtime else RUNTIME_CANDIDATES
    for candidate in candidates:
        if candidate and os.path.isfile(candidate) and os.access(candidate, os.X_OK):
            return Path(candidate).resolve()
    return None


def collect_dependencies(start_path, search_dirs):
    pending = [start_path]
    copied = {}

    while pending:
        current = pending.pop()
        for dep in macho_dependencies(current):
            resolved = resolve_dependency(dep, current, search_dirs)
            if resolved is None or resolved in copied:
                continue
            copied[resolved] = Path(dep).name
            pending.append(resolved)

    return copied


def copy_runtime(runtime_path, resources_dir, search_dirs):
    bin_dir = resources_dir / "bin"
    lib_dir = resources_dir / "lib"
    bin_dir.mkdir(parents=True, exist_ok=True)
    lib_dir.mkdir(parents=True, exist_ok=True)

    runtime_dest = bin_dir / runtime_path.name
    shutil.copy2(runtime_path, runtime_dest)
    runtime_dest.chmod(runtime_dest.stat().st_mode | 0o755)

    copied_libraries = collect_dependencies(runtime_path, search_dirs)
    lib_destinations = []
    for source, dest_name in copied_libraries.items():
        dest = lib_dir / dest_name
        shutil.copy2(source, dest)
        dest.chmod(dest.stat().st_mode | 0o644)
        lib_destinations.append(dest)

    patch_macho(runtime_dest, is_library=False)
    for lib in lib_destinations:
        patch_macho(lib, is_library=True)

    return runtime_dest, lib_destinations


def patch_macho(path, is_library):
    if is_library:
        run(["install_name_tool", "-id", f"@rpath/{path.name}", str(path)])

    existing_rpaths = set(macho_rpaths(path))
    if not is_library and "@loader_path/../lib" not in existing_rpaths:
        run(["install_name_tool", "-add_rpath", "@loader_path/../lib", str(path)])

    for dep in macho_dependencies(path):
        if is_system_dependency(dep):
            continue
        run(["install_name_tool", "-change", dep, f"@rpath/{Path(dep).name}", str(path)])


def main():
    parser = argparse.ArgumentParser(description="Bundle llama.cpp runtime into MacDictate.app resources.")
    parser.add_argument("--resources", required=True, help="Path to MacDictate.app/Contents/Resources")
    parser.add_argument("--runtime", default="", help="Optional path to llama-completion or llama-cli")
    args = parser.parse_args()

    resources_dir = Path(args.resources)
    runtime_path = find_runtime(args.runtime)
    if runtime_path is None:
        print("llama.cpp runtime not found. Install llama.cpp or set MACDICTATE_LLAMA_RUNTIME_PATH.", file=sys.stderr)
        return 1

    runtime_dest, libraries = copy_runtime(
        runtime_path,
        resources_dir,
        [str(Path(path).resolve()) for path in DEFAULT_SEARCH_DIRS if Path(path).exists()]
    )

    print(f"Bundled llama runtime: {runtime_dest}")
    for lib in sorted(libraries):
        print(f"Bundled llama dependency: {lib}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
