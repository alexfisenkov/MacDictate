#!/usr/bin/env python3
"""Validate Windows channels and, optionally, exact packaged build bytes. No network."""
import argparse
import hashlib
import json
import re
import subprocess
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def require(condition, message):
    if not condition:
        raise ValueError(message)


def digest(path):
    value = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            value.update(block)
    return value.hexdigest()


def validate(root, build_manifest=None, source_sha=None):
    registry = json.loads((root / 'releases/registry.json').read_text())
    channel = registry['current'].get('windows')
    require(channel is not None, 'registry.current.windows must define independent stable/working channels')
    entries = {item['version']: item for item in registry['versions']}
    stable = entries[channel['publicStable']]
    require(stable['status'] in ('public_stable', 'public_release'), 'Windows stable must point to an actually published ledger entry')
    windows = stable['windows']
    manifest = json.loads((root / 'web-landing/downloads/latest-windows.json').read_text())
    require(manifest['schemaVersion'] == 1 and manifest['platform'] == 'win-x64', 'Windows public manifest schema/platform mismatch')
    require(manifest['version'] == stable['version'], 'Windows public manifest must name Windows publicStable')
    require(re.fullmatch(r'[0-9a-f]{40}', manifest['sourceSHA']) is not None, 'Invalid Windows public sourceSHA')
    require(manifest['sourceSHA'] == windows['sourceSHA'], 'Windows public sourceSHA differs from ledger')
    require(manifest['signed'] == windows['signed'], 'Windows signing disclosure differs from ledger')
    release = stable['github']['releaseUrl']
    require(manifest['githubReleaseUrl'] == release and manifest['publishedAt'] == stable['github']['publishedAt'] and manifest['publishedAt'], 'Windows public release identity missing or inconsistent')
    require(manifest['minimumWindowsBuild'] == windows['minimumWindowsBuild'] and manifest['ciRunURL'] == windows['ciRunURL'], 'Windows support/CI metadata differs from ledger')
    base = release.replace('/tag/', '/download/') + '/'
    for kind in ('installer', 'portable'):
        name = windows[kind + 'AssetName']
        extension = 'exe' if kind == 'installer' else 'zip'
        require(name == f"MacDictate_Windows_{stable['version']}_x64.{extension}", f'{kind} name must match the stable Windows version')
        checksum = windows[kind + 'Sha256']
        require(re.fullmatch(r'[0-9a-f]{64}', checksum) is not None, f'Invalid {kind} SHA256')
        require(manifest[kind + 'AssetName'] == name and manifest[kind + 'Sha256'] == checksum, f'{kind} manifest/ledger mismatch')
        require(manifest[kind + 'Url'] == base + name, f'{kind} URL must pin the exact release tag and asset')
    project = ET.parse(root / 'windows/src/MacDictate.Windows/MacDictate.Windows.csproj')
    version = project.findtext('./PropertyGroup/Version')
    working = entries[channel['workingLine']]
    require(working['status'] == 'working_line' and working['platform'] == 'win-x64', 'Windows working entry must be an unpublished Windows working_line')
    require(working['windows']['version'] == version, 'Windows working version differs from canonical csproj Version')
    require(channel['releaseTag'] == 'v' + version and channel['makeLatest'] is False, 'Windows-only candidate must use its own tag and makeLatest=false')
    require(working['github']['publishedAt'] is None and working['windows']['sourceSHA'] is None, 'Unbuilt candidate must not claim publication or artifact sourceSHA')
    html = (root / 'web-landing/index.html').read_text()
    require('releases/latest/download/MacDictate_Windows' not in html, 'Windows must not depend on global Mac latest')
    require('data-windows-asset="installer"' in html and 'data-windows-asset="portable"' in html, 'Windows download roles missing')
    require('latest-windows.json' in html, 'Landing must read the canonical Windows public manifest')
    if build_manifest:
        path = Path(build_manifest)
        build = json.loads(path.read_text(encoding='utf-8-sig'))
        require(build['schemaVersion'] == 1 and build['platform'] == 'windows-x64', 'Build manifest schema/platform mismatch')
        require(build['version'] == version and build['signed'] is False, 'Build manifest version/signing mismatch')
        expected_sha = source_sha or subprocess.check_output(['git', '-C', str(root), 'rev-parse', 'HEAD'], text=True).strip()
        require(re.fullmatch(r'[0-9a-f]{40}', expected_sha) is not None, 'Expected build sourceSHA must be a full Git SHA')
        require(build['sourceSHA'] == expected_sha, 'Build manifest sourceSHA is not the checked source SHA')
        lock = json.loads((root / 'windows/runtime-lock.json').read_text())
        require(build['runtime'] == lock['whisper'] and build['model'] == lock['model'], 'Build runtime/model pins differ from source')
        names = {f'MacDictate_Windows_v{version}_x64.{extension}' for extension in ('exe', 'zip')}
        require({item['name'] for item in build['artifacts']} == names and len(build['artifacts']) == 2, 'Build package set differs from canonical version')
        sums = []
        for item in build['artifacts']:
            artifact = path.parent / item['name']
            require(artifact.is_file() and artifact.stat().st_size == item['bytes'], 'Build package missing or byte count mismatch')
            require(digest(artifact) == item['sha256'], 'Build package SHA256 mismatch')
            sums.append(f"{item['sha256']}  {item['name']}")
        require(set((path.parent / 'WINDOWS-SHA256SUMS').read_text().splitlines()) == set(sums), 'Windows checksums differ from actual build packages')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=ROOT)
    parser.add_argument('--build-manifest', type=Path)
    parser.add_argument('--source-sha')
    args = parser.parse_args()
    try:
        validate(args.root, args.build_manifest, args.source_sha)
    except (ValueError, KeyError, OSError, ET.ParseError, json.JSONDecodeError) as error:
        parser.exit(1, f'Windows delivery FAIL: {error}\n')
    print('Windows delivery PASS: independent channels, pinned public manifest, canonical candidate' + (' and exact artifact bytes/sourceSHA' if args.build_manifest else ''))
