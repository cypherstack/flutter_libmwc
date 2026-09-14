import struct
import unittest

from audit import archive, macho


TARGET = 'aarch64-apple-darwin'


def string_command(command, name):
    content = name.encode() + b'\0'
    content += b'\0' * (-(24 + len(content)) % 8)
    return struct.pack('<6I', command, 24 + len(content), 24, 0, 0, 0) + content


def binary(minimum=11 << 16, cpu=0x100000c, dynamic=True, extra=b'', dependency='/usr/lib/libSystem.B.dylib'):
    commands = [struct.pack('<6I', 0x32, 24, 1, minimum, 0xe0400, 0)]
    if dynamic:
        commands += [string_command(0xd, '@rpath/libmwc_wallet.dylib'), string_command(0xc, dependency)]
    if extra:
        commands.append(extra)
    return struct.pack('<8I', 0xfeedfacf, cpu, 0, 6 if dynamic else 1,
                       len(commands), sum(map(len, commands)), 0, 0) + b''.join(commands)


def static_archive(payload, timestamp=0):
    header = f'{"object.o/":<16}{timestamp:<12}{0:<6}{0:<6}{"644":<8}{len(payload):<10}`\n'.encode()
    return b'!<arch>\n' + header + payload + (b'\n' if len(payload) % 2 else b'')


class AuditTests(unittest.TestCase):
    def test_valid_dylib_and_archive(self):
        self.assertEqual(macho(binary(), TARGET, True)['minimum_versions'], [11 << 16])
        self.assertEqual(archive(static_archive(binary(dynamic=False)), TARGET), 1)

    def test_rejects_higher_floor_in_either_link_mode(self):
        with self.assertRaisesRegex(ValueError, 'newer'):
            macho(binary(minimum=14 << 16), TARGET, True)
        with self.assertRaisesRegex(ValueError, 'newer'):
            archive(static_archive(binary(minimum=14 << 16, dynamic=False)), TARGET)

    def test_rejects_wrong_architecture(self):
        with self.assertRaisesRegex(ValueError, 'architecture'):
            macho(binary(cpu=0x1000007), TARGET, True)

    def test_rejects_non_system_dependency(self):
        with self.assertRaisesRegex(ValueError, 'Non-system'):
            macho(binary(dependency='/nix/store/example/lib/libc++.dylib'), TARGET, True)

    def test_rejects_uuid_and_rpath(self):
        for command in (0x1b, 0x8000001c):
            with self.subTest(command=command), self.assertRaisesRegex(ValueError, 'UUID'):
                macho(binary(extra=struct.pack('<II', command, 8)), TARGET, True)

    def test_rejects_timestamp(self):
        with self.assertRaisesRegex(ValueError, 'timestamp'):
            archive(static_archive(binary(dynamic=False), timestamp=123), TARGET)

    def test_duplicate_names_have_deterministic_sequence(self):
        member = binary(dynamic=False)
        valid = static_archive(member, timestamp=1) + static_archive(member, timestamp=2)[8:]
        self.assertEqual(archive(valid, TARGET), 2)
        invalid = static_archive(member) + static_archive(member)[8:]
        with self.assertRaisesRegex(ValueError, 'timestamp'):
            archive(invalid, TARGET)

    def test_rejects_truncated_bytes(self):
        with self.assertRaisesRegex(ValueError, 'Truncated'):
            macho(binary()[:-1], TARGET, True)
        with self.assertRaisesRegex(ValueError, 'Truncated'):
            archive(static_archive(binary(dynamic=False))[:-1], TARGET)


if __name__ == '__main__':
    unittest.main()
