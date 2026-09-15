"""Reject the wrong native target, timestamped archives, and unexpected imports."""
import re
import struct

ALLOWED_IMPORTS = {
    'api-ms-win-core-synch-l1-2-0.dll', 'bcryptprimitives.dll', 'ws2_32.dll',
    'kernel32.dll', 'advapi32.dll', 'ole32.dll', 'oleaut32.dll', 'pdh.dll',
    'powrprof.dll', 'psapi.dll', 'ntdll.dll', 'iphlpapi.dll', 'shell32.dll',
    'netapi32.dll', 'secur32.dll', 'crypt32.dll', 'bcrypt.dll', 'msvcp140.dll',
    'vcruntime140.dll', 'api-ms-win-crt-string-l1-1-0.dll',
    'api-ms-win-crt-heap-l1-1-0.dll', 'api-ms-win-crt-math-l1-1-0.dll',
    'api-ms-win-crt-runtime-l1-1-0.dll', 'api-ms-win-crt-stdio-l1-1-0.dll',
}


def audit(dll, archive, headers, dependents, exports):
    data = dll.read_bytes()
    if data[:2] != b'MZ':
        raise ValueError('Expected a PE DLL')
    pe = struct.unpack_from('<I', data, 0x3c)[0]
    if data[pe:pe + 4] != b'PE\0\0' or struct.unpack_from('<H', data, pe + 4)[0] != 0x8664:
        raise ValueError('Expected x64 MSVC PE')
    if struct.unpack_from('<H', data, pe + 24)[0] != 0x20b:
        raise ValueError('Expected PE32+')
    if not struct.unpack_from('<H', data, pe + 22)[0] & 0x2000:
        raise ValueError('Expected a DLL')
    # The linker emits a content-derived PE timestamp and IMAGE_DEBUG_TYPE_REPRO.
    if not re.search(r'\brepro\s', headers) or 'RSDS' in headers:
        raise ValueError('Missing reproducible PE marker or embedded PDB record')
    imports = {line.strip().lower() for line in dependents.splitlines()
               if re.fullmatch(r'\s+[\w.-]+\.dll\s*', line, re.I)}
    if not imports or imports - ALLOWED_IMPORTS:
        raise ValueError(f'Unexpected DLL imports: {sorted(imports - ALLOWED_IMPORTS)}')
    for symbol in ['mwc_get_mnemonic', 'mwc_rust_open_wallet', 'mwc_string_free']:
        if not re.search(r'\b' + symbol + r'\b', exports):
            raise ValueError(f'Missing C export: {symbol}')
    data = archive.read_bytes()
    if not data.startswith(b'!<arch>\n'):
        raise ValueError('Expected a COFF archive')
    offset, objects, object_timestamps = 8, 0, 0
    while offset < len(data):
        header = data[offset:offset + 60]
        if len(header) != 60 or header[58:] != b'`\n':
            raise ValueError('Malformed archive member')
        size = int(header[48:58])
        if header[16:28].strip() not in (b'', b'0'):
            raise ValueError('Archive member has a nonzero timestamp')
        member = data[offset + 60:offset + 60 + size]
        if len(member) != size:
            raise ValueError('Truncated archive member')
        if header[:16].strip() not in (b'/', b'//'):
            bigobj = member[:4] == b'\x00\x00\xff\xff'
            if struct.unpack_from('<H', member, 6 if bigobj else 0)[0] != 0x8664:
                raise ValueError('Non-x64 archive member')
            if struct.unpack_from('<I', member, 8 if bigobj else 4)[0] != 0:
                # MSVC /Brepro uses a content-derived value here. Its stability
                # is checked by whole-file comparison, never by zeroing bytes.
                object_timestamps += 1
            objects += 1
        offset += 60 + size + size % 2
    if offset != len(data) or not objects:
        raise ValueError('Malformed or empty COFF archive')
    return {'coff_objects': objects, 'imports': sorted(imports), 'machine': 'x64',
            'nonzero_object_timestamps': object_timestamps,
            'pe_repro_marker': True, 'archive_timestamps': 'zero'}
