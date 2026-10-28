#!/usr/bin/env python3
"""Exercise delivery validation with Windows cp1252 as the implicit text codec."""
import hashlib
import importlib.util
import json
import tempfile
import unittest
import xml.etree.ElementTree as ET
from pathlib import Path
from unittest.mock import patch

SCRIPT = Path(__file__).with_name('check-delivery.py')
SPEC = importlib.util.spec_from_file_location('delivery', SCRIPT)
delivery = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(delivery)


class DeliveryEncodingTests(unittest.TestCase):
    def test_utf8_sources_and_build_validation_under_cp1252(self):
        root = delivery.ROOT
        version = ET.parse(root / 'windows/src/MacDictate.Windows/MacDictate.Windows.csproj').findtext('./PropertyGroup/Version')
        lock = json.loads((root / 'windows/runtime-lock.json').read_bytes())
        original_read_text = Path.read_text

        def windows_default_read_text(path, encoding=None, errors=None, **kwargs):
            return original_read_text(path, encoding=encoding or 'cp1252', errors=errors, **kwargs)

        with tempfile.TemporaryDirectory(prefix='macdictate-encoding-') as directory:
            output = Path(directory)
            artifacts = []
            for extension in ('exe', 'zip'):
                name = f'MacDictate_Windows_v{version}_x64.{extension}'
                content = b'SYNTHETIC package for encoding regression ' + extension.encode('ascii')
                (output / name).write_bytes(content)
                artifacts.append({'name': name, 'bytes': len(content), 'sha256': hashlib.sha256(content).hexdigest()})
            source_sha = 'a' * 40
            manifest = {'schemaVersion': 1, 'platform': 'windows-x64', 'version': version, 'signed': False,
                        'sourceSHA': source_sha, 'runtime': lock['whisper'], 'model': lock['model'], 'artifacts': artifacts}
            manifest_path = output / 'windows-build-manifest.json'
            manifest_path.write_text(json.dumps(manifest, ensure_ascii=False), encoding='utf-8-sig')
            sums = '\n'.join(f"{item['sha256']}  {item['name']}" for item in artifacts) + '\n'
            (output / 'WINDOWS-SHA256SUMS').write_text(sums, encoding='ascii')
            with patch.object(Path, 'read_text', windows_default_read_text):
                # Actual UTF-8 repository sources contain Cyrillic, including cp1252-undefined bytes.
                delivery.validate(root, manifest_path, source_sha)
                # Locale repair must retain source-identity and digest validation.
                with self.assertRaisesRegex(ValueError, 'sourceSHA'):
                    delivery.validate(root, manifest_path, 'b' * 40)
                package = output / artifacts[0]['name']
                package.write_bytes(package.read_bytes().replace(b'SYNTHETIC', b'TAMPERED!'))
                with self.assertRaisesRegex(ValueError, 'SHA256'):
                    delivery.validate(root, manifest_path, source_sha)


if __name__ == '__main__':
    unittest.main()
