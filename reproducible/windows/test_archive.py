"""Behavior checks for path-independent COFF metadata reconstruction."""
from pathlib import Path
import struct
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parent))
from archive import canonical_archive, members, object_members, record


def fixture(prefix):
    header = (f"{'/':<16}{0:<12}{0:<6}{0:<6}{0:<8}{0:<10}`\n").encode()
    names = (prefix + '/same.obj\0' + prefix + '/same.obj\0').encode()
    obj = struct.pack('<HHIIIHH', 0x8664, 0, 0, 0, 0, 0, 0)
    objects = [obj + b'first', obj + b'second']
    # Both indexes select the second duplicate, deliberately.
    first = struct.pack('>II', 1, 0) + b'symbol\0\0'
    second = struct.pack('<IIIIH', 2, 0, 0, 1, 2) + b'symbol\0\0'
    metadata_size = sum(len(record(b'/', p, header)) for p in [first, second, names])
    offsets = [8 + metadata_size]
    offsets.append(offsets[0] + len(record(b'/0', objects[0], header)))
    first = struct.pack('>II', 1, offsets[1]) + b'symbol\0\0'
    second = struct.pack('<IIIIH', 2, *offsets, 1, 2) + b'symbol\0\0'
    return (b'!<arch>\n' + record(b'/', first, header) + record(b'/', second, header)
            + record(b'//', names, header) + record(b'/0', objects[0], header)
            + record(('/' + str(names.index(0) + 1)).encode(), objects[1], header))


class ArchiveTests(unittest.TestCase):
    def test_paths_removed_without_losing_duplicate_members_or_selection(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            outputs = []
            for i, prefix in enumerate(['C:/short', 'D:/different path/longer']):
                source, dest = root / f'{i}.lib', root / f'{i}-out.lib'
                source.write_bytes(fixture(prefix))
                evidence = canonical_archive(source, dest)
                self.assertEqual(evidence['members'], 2)
                items = members(dest.read_bytes())
                objs = list(object_members(items))
                self.assertEqual([x[2] for x in objs],
                                 [x[2] for x in object_members(members(source.read_bytes()))])
                self.assertEqual(struct.unpack_from('>I', items[0][2], 4)[0], objs[1][0])
                self.assertEqual(struct.unpack_from('<H', items[1][2], 16)[0], 2)
                self.assertEqual(items[2][2], b'same.obj\0same.obj\0')
                outputs.append(dest.read_bytes())
            self.assertEqual(*outputs)

    def test_invalid_symbol_binding_rejected_without_output(self):
        with tempfile.TemporaryDirectory() as temporary:
            source, dest = Path(temporary) / 'in.lib', Path(temporary) / 'out.lib'
            data = bytearray(fixture('C:/src'))
            struct.pack_into('>I', data, 8 + 60 + 4, 123)
            source.write_bytes(data)
            with self.assertRaisesRegex(ValueError, 'outside the object members'):
                canonical_archive(source, dest)
            self.assertFalse(dest.exists())


if __name__ == '__main__':
    unittest.main()
