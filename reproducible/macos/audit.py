#!/usr/bin/env python3
"""Audit shipped Mach-O bytes without depending on the host's Xcode tools."""
import argparse
from collections import Counter
import json
from pathlib import Path
import struct


CPUS = {'aarch64-apple-darwin': 0x100000c, 'x86_64-apple-darwin': 0x1000007}
FLOOR = 11 << 16


def macho(data, target, dynamic=False):
    if len(data) < 32 or data[:4] != b'\xcf\xfa\xed\xfe':
        raise ValueError('Expected a thin, little-endian 64-bit Mach-O')
    _, cpu, _, kind, count, size, _, _ = struct.unpack_from('<8I', data)
    if cpu != CPUS[target] or kind != (6 if dynamic else 1):
        raise ValueError('Wrong architecture or Mach-O file type')
    end = 32 + size
    if end > len(data):
        raise ValueError('Truncated load commands')
    offset = 32
    versions, dependencies, identities = [], [], []
    for _ in range(count):
        if offset + 8 > end:
            raise ValueError('Truncated load command')
        cmd, length = struct.unpack_from('<II', data, offset)
        if length < 8 or offset + length > end:
            raise ValueError('Invalid load command size')
        command = data[offset:offset + length]
        if cmd == 0x32:  # LC_BUILD_VERSION
            if length < 24:
                raise ValueError('Truncated build version')
            platform, minimum, sdk = struct.unpack_from('<III', command, 8)
            if platform != 1 or minimum > FLOOR:
                raise ValueError('Requires a platform newer than macOS 11')
            versions.append(minimum)
        elif cmd == 0x24:  # LC_VERSION_MIN_MACOSX
            if length < 16:
                raise ValueError('Truncated minimum version')
            minimum, sdk = struct.unpack_from('<II', command, 8)
            if minimum > FLOOR:
                raise ValueError('Requires a platform newer than macOS 11')
            versions.append(minimum)
        elif cmd in (0xc, 0xd, 0x80000018, 0x8000001f, 0x20, 0x80000023):
            if length < 24:
                raise ValueError('Truncated dylib command')
            start = struct.unpack_from('<I', command, 8)[0]
            if not 24 <= start < length or b'\0' not in command[start:]:
                raise ValueError('Invalid dylib name')
            name = command[start:].split(b'\0', 1)[0].decode()
            (identities if cmd == 0xd else dependencies).append(name)
        elif cmd in (0x1b, 0x8000001c):  # UUID / RPATH
            raise ValueError('Unexpected UUID or runtime search path')
        offset += length
    if offset != end:
        raise ValueError('Load command count/size mismatch')
    if dynamic:
        if versions != [FLOOR]:
            raise ValueError('The dylib must declare exactly macOS 11.0')
        if identities != ['@rpath/libmwc_wallet.dylib']:
            raise ValueError('Wrong dylib install name')
        if not dependencies or any(not name.startswith(('/usr/lib/', '/System/Library/Frameworks/'))
                                   for name in dependencies):
            raise ValueError(f'Non-system dynamic dependency: {dependencies}')
    return {'minimum_versions': sorted(set(versions)), 'dependencies': dependencies}


def archive(data, target):
    if not data.startswith(b'!<arch>\n'):
        raise ValueError('Expected a static archive')
    offset, members = 8, 0
    timestamps = []
    while offset < len(data):
        header = data[offset:offset + 60]
        if len(header) != 60 or header[58:] != b'`\n':
            raise ValueError('Invalid archive member header')
        for field in (header[28:34], header[34:40]):
            if int(field.strip() or b'0') != 0:
                raise ValueError('Nonzero archive uid or gid')
        size = int(header[48:58])
        start = offset + 60
        if size < 0 or start + size > len(data):
            raise ValueError('Truncated archive member')
        name = header[:16].rstrip()
        payload = data[start:start + size]
        if name.startswith(b'#1/'):
            length = int(name[3:])
            if not 0 < length <= size:
                raise ValueError('Invalid extended archive name')
            name, payload = payload[:length].rstrip(b'\0'), payload[length:]
        timestamps.append((name, int(header[16:28].strip() or b'0')))
        if not name.startswith(b'__.SYMDEF') and name not in (b'/', b'//', b'/SYM64/'):
            macho(payload, target)
            members += 1
        offset = start + size + (size % 2)
    if offset != len(data) or not members:
        raise ValueError('Empty or malformed static archive')
    # LLVM's deterministic Darwin writer distinguishes duplicate names with
    # timestamps 1, 2, ...; unique names have timestamp zero. Keep those bytes.
    counts = Counter(name for name, _ in timestamps)
    seen = Counter()
    for name, timestamp in timestamps:
        seen[name] += 1
        expected = seen[name] if counts[name] > 1 else 0
        if timestamp != expected:
            raise ValueError('Nondeterministic archive timestamp')
    return members


def audit(directory, target):
    dynamic = (directory / 'libmwc_wallet.dylib').read_bytes()
    static = (directory / 'libmwc_wallet.a').read_bytes()
    for data in (static, dynamic):
        if any(path in data for path in (b'/Users/', b'/private/tmp/nix-build-',
                                        b'/private/var/folders/', b'/nix/var/nix/builds/')):
            raise ValueError('Embedded host checkout/build path')
    return {'target': target, 'dylib': macho(dynamic, target, dynamic=True),
            'archive_members': archive(static, target)}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('directory', type=Path)
    parser.add_argument('--target', choices=CPUS, required=True)
    args = parser.parse_args()
    print(json.dumps(audit(args.directory, args.target), sort_keys=True))
