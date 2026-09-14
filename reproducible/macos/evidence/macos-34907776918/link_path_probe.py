#!/usr/bin/env python3
"""Reproduce a stale Mach-O UUID caused by post-link debug stripping."""
import argparse
import ctypes
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import tempfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('pins', type=Path, help='JSON from nix eval .#native-macos.pinnedInputs')
args = parser.parse_args()
pins = json.loads(args.pins.read_text())
clang = pins['clang']['path'] + '/bin/clang'
linker = pins['linker']['path'] + '/bin/ld64.lld'
sdk = pins['sdk']['path']
objcopy = pins['rust']['path'] + '/lib/rustlib/aarch64-apple-darwin/bin/rust-objcopy'
base = [clang, '-isysroot', sdk, '-mmacosx-version-min=11.0']
results = {}
with tempfile.TemporaryDirectory(prefix='mwc-link-path-') as temporary:
    root = Path(temporary)
    source = root / 'probe.c'
    source.write_text('int mwc_link_path_probe(void) { return 42; }\n')
    shared = root / 'shared.o'
    subprocess.run(base + ['-g', '-c', str(source), '-o', str(shared)], check=True)
    for mode in ('post-link-only', 'link-time-strip'):
        hashes = []
        for directory in ('a', 'a-much-longer-path-b'):
            folder = root / mode / directory
            folder.mkdir(parents=True)
            obj = folder / 'probe.o'
            shutil.copy2(shared, obj)
            output = folder / 'libprobe.dylib'
            command = base + ['--ld-path=' + linker, '-dynamiclib', str(obj),
                              '-Wl,-install_name,@rpath/libprobe.dylib', '-o', str(output)]
            if mode == 'link-time-strip':
                command += ['-Wl,-S']
            subprocess.run(command, check=True)
            subprocess.run([objcopy, '--strip-debug', str(output)], check=True)
            hashes.append(hashlib.sha256(output.read_bytes()).hexdigest())
            if mode == 'link-time-strip':
                library = ctypes.CDLL(str(output))
                assert library.mwc_link_path_probe() == 42
        results[mode] = {'hashes': hashes, 'match': hashes[0] == hashes[1]}
assert not results['post-link-only']['match'], 'The original failure did not reproduce'
assert results['link-time-strip']['match'], 'Link-time stripping did not fix path sensitivity'
print(json.dumps(results, indent=2, sort_keys=True))
