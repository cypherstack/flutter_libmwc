import hashlib
import json
from pathlib import Path
import struct
import sys
import tempfile
import unittest
from unittest import mock
import zipfile

sys.path.insert(0, str(Path(__file__).resolve().parent))
import provision
from audit import audit


class ProvisionTests(unittest.TestCase):
    def test_corrupt_cached_tools_are_rejected(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / 'tool.zip').write_bytes(b'corrupt')
            (root / 'tools.lock.json').write_text(json.dumps([{
                'id': 'tool', 'archive': 'tool.zip', 'sha256': '0' * 64,
                'kind': 'cmake', 'url': 'https://example.invalid/unused',
            }]))
            def bad_download(url, destination):
                Path(destination).write_bytes(b'also corrupt')
            with mock.patch.object(provision, '__file__', str(root / 'provision.py')), mock.patch.object(
                    provision.urllib.request, 'urlretrieve', side_effect=bad_download):
                with self.assertRaisesRegex(ValueError, 'Download digest mismatch'):
                    provision.provision(root / 'output', root)
            self.assertEqual((root / 'tool.zip').read_bytes(), b'corrupt')
            self.assertEqual(list(root.glob('*.download')), [])

    def test_archive_cannot_escape_tool_directory(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            archive = root / 'tool.zip'
            with zipfile.ZipFile(archive, 'w') as output:
                output.writestr('../../escaped.txt', 'bad')
            (root / 'tools.lock.json').write_text(json.dumps([{
                'id': 'tool', 'archive': 'tool.zip',
                'sha256': hashlib.sha256(archive.read_bytes()).hexdigest(),
                'kind': 'cmake', 'url': 'https://example.invalid/unused',
            }]))
            with mock.patch.object(provision, '__file__', str(root / 'provision.py')):
                with self.assertRaisesRegex(ValueError, 'Unsafe archive member'):
                    provision.provision(root / 'output', root)
            self.assertFalse((root / 'escaped.txt').exists())

    def test_existing_destination_is_never_overwritten(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            with self.assertRaisesRegex(ValueError, 'must be fresh'):
                provision.provision(root, root / 'cache')


class AuditTests(unittest.TestCase):
    def test_rejects_wrong_target_imports_and_timestamped_archives(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            dll = root / 'test.dll'
            data = bytearray(256)
            data[:2] = b'MZ'
            struct.pack_into('<I', data, 0x3c, 64)
            data[64:68] = b'PE\0\0'
            struct.pack_into('<H', data, 68, 0x8664)
            struct.pack_into('<H', data, 86, 0x2000)
            struct.pack_into('<H', data, 88, 0x20b)
            dll.write_bytes(data)
            obj = struct.pack('<HHIIIHH', 0x8664, 0, 0, 0, 0, 0, 0)
            header = (f"{'test.obj/':<16}{0:<12}{0:<6}{0:<6}{0:<8}{len(obj):<10}`\n").encode()
            library = root / 'test.lib'
            library.write_bytes(b'!<arch>\n' + header + obj)
            options = dict(headers='00000000 repro   24', dependents='    kernel32.dll',
                exports='mwc_get_mnemonic mwc_rust_open_wallet mwc_string_free')
            self.assertEqual(audit(dll, library, **options)['coff_objects'], 1)
            with self.assertRaisesRegex(ValueError, 'Unexpected DLL imports'):
                audit(dll, library, **{**options, 'dependents': '    libcrypto.dll'})
            with self.assertRaisesRegex(ValueError, 'PDB'):
                audit(dll, library, **{**options, 'headers': 'repro 24 RSDS'})
            changed = bytearray(library.read_bytes())
            changed[24] = ord('1')
            library.write_bytes(changed)
            with self.assertRaisesRegex(ValueError, 'nonzero timestamp'):
                audit(dll, library, **options)
            struct.pack_into('<H', data, 68, 0x14c)
            dll.write_bytes(data)
            with self.assertRaisesRegex(ValueError, 'x64'):
                audit(dll, library, **options)


if __name__ == '__main__':
    unittest.main()
