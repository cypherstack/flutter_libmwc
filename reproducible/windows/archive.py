"""Canonicalize COFF member names while preserving symbol-selection semantics.

Format: https://learn.microsoft.com/windows/win32/debug/pe-format
Only archive metadata is rebuilt. Object bytes, member order, duplicate members,
and both original symbol-to-member mappings are preserved exactly.
"""
import hashlib
import struct


def members(data):
    if data[:8] != b'!<arch>\n':
        raise ValueError('Expected a regular COFF library')
    offset, result = 8, []
    while offset < len(data):
        header = data[offset:offset + 60]
        if len(header) != 60 or header[58:] != b'`\n':
            raise ValueError('Malformed archive header')
        size = int(header[48:58])
        if size < 0 or offset + 60 + size > len(data):
            raise ValueError('Invalid archive member size')
        result.append((offset, header, data[offset + 60:offset + 60 + size]))
        offset += 60 + size + size % 2
    if offset != len(data):
        raise ValueError('Malformed COFF archive padding')
    if len(result) < 3 or [m[1][:16].strip() for m in result[:2]] != [b'/', b'/']:
        raise ValueError('Expected both Microsoft linker members')
    return result


def object_members(items):
    for item in items[2:]:
        name = item[1][:16].strip()
        if name == b'//':
            continue
        if name.startswith(b'/') and not name[1:].isdigit():
            raise ValueError('Unsupported COFF archive member')
        payload = item[2]
        bigobj = payload[:4] == b'\x00\x00\xff\xff'
        if len(payload) < 20 or struct.unpack_from('<H', payload, 6 if bigobj else 0)[0] != 0x8664:
            raise ValueError('Expected x64 COFF object')
        yield item


def objects(path):
    return (item[2] for item in object_members(members(path.read_bytes())))


def relocate_index(payload, byte_order, offsets, second=False):
    output = bytearray(payload)
    count = struct.unpack_from(byte_order + 'I', output)[0]
    if 4 + 4 * count > len(output):
        raise ValueError('Truncated linker offset table')
    for position in range(4, 4 + 4 * count, 4):
        old = struct.unpack_from(byte_order + 'I', output, position)[0]
        if old not in offsets:
            raise ValueError('Linker index points outside the object members')
        struct.pack_into(byte_order + 'I', output, position, offsets[old])
    tail = 4 + 4 * count
    if second:
        symbols = struct.unpack_from('<I', output, tail)[0]
        indices = output[tail + 4:tail + 4 + symbols * 2]
        if len(indices) != symbols * 2 or any(
                not 1 <= index[0] <= count for index in struct.iter_unpack('<H', indices)):
            raise ValueError('Invalid second-linker symbol indices')
        tail += 4 + symbols * 2
    else:
        symbols = count
    # MSVC includes a final zero byte in the member size when the symbol
    # strings require even alignment. Consume exactly the declared strings,
    # then accept only that optional alignment byte.
    cursor = tail
    for _ in range(symbols):
        end = output.find(0, cursor)
        if end < cursor or end == cursor:
            raise ValueError('Invalid linker symbol string table')
        cursor = end + 1
    if output[cursor:] not in (b'', b'\x00'):
        raise ValueError('Invalid linker symbol string padding')
    return bytes(output)


def record(name, payload, original_header):
    header = bytearray(original_header)
    header[:16] = name.ljust(16, b' ')
    header[16:28] = b'0'.ljust(12, b' ')
    header[48:58] = str(len(payload)).encode('ascii').ljust(10, b' ')
    return bytes(header) + payload + (b'\n' if len(payload) % 2 else b'')


def canonical_archive(source, destination):
    if destination.exists():
        raise ValueError('Archive destination must be fresh')
    original = members(source.read_bytes())
    objs = list(object_members(original))
    if not objs:
        raise ValueError('Cannot package an empty library')
    # Preserve basenames: renaming every object to an ordinal changes MSVC
    # link behavior even with identical object bytes and symbol bindings.
    # Duplicate names remain separate members; no object is deduplicated.
    tables = [m for m in original[2:] if m[1][:16].strip() == b'//']
    if len(tables) != 1:
        raise ValueError('Expected one long-name table')
    old_names = tables[0][2]
    names, new_names = [], bytearray()
    for _, header, _ in objs:
        name = header[:16].strip()
        if name.startswith(b'/'):
            start = int(name[1:])
            end = old_names.find(b'\x00', start)
            if start >= len(old_names) or end < start:
                raise ValueError('Invalid archive member name offset')
            name = old_names[start:end]
        else:
            name = name.rstrip(b'/')
        name = name.replace(b'\\', b'/').rsplit(b'/', 1)[-1]
        if not name:
            raise ValueError('Empty archive member basename')
        names.append(b'/' + str(len(new_names)).encode('ascii'))
        new_names.extend(name + b'\x00')
    long_record = record(b'//', bytes(new_names), tables[0][1])
    position = 8 + sum(60 + len(m[2]) + len(m[2]) % 2 for m in original[:2]) + len(long_record)
    offsets = {}
    records = []
    for name, (old, header, payload) in zip(names, objs):
        offsets[old] = position
        entry = record(name, payload, header)
        records.append(entry)
        position += len(entry)
    first = relocate_index(original[0][2], '>', offsets)
    second = relocate_index(original[1][2], '<', offsets, second=True)
    output = b'!<arch>\n' + record(b'/', first, original[0][1]) + record(b'/', second, original[1][1]) + long_record + b''.join(records)
    rebuilt = members(output)
    new_objs = list(object_members(rebuilt))
    if [o[2] for o in new_objs] != [o[2] for o in objs]:
        raise ValueError('Object payloads or ordering changed')
    # Restore the old offsets and require the complete original index bytes.
    # This checks duplicate-symbol precedence as well as every symbol spelling.
    backwards = {new: old for old, new in offsets.items()}
    if (relocate_index(rebuilt[0][2], '>', backwards) != original[0][2] or
            relocate_index(rebuilt[1][2], '<', backwards, second=True) != original[1][2]):
        raise ValueError('Symbol-to-member bindings changed')
    destination.parent.mkdir(parents=True, exist_ok=True)
    with destination.open('xb') as stream:
        stream.write(output)
    return {'members': len(objs), 'symbol_bindings_preserved': True,
            'ordered_payloads_sha256': hashlib.sha256(b''.join(
                hashlib.sha256(o[2]).digest() for o in objs)).hexdigest()}
