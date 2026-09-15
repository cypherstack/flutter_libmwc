"""Build both MSVC link modes with an isolated, pinned native toolchain."""
import argparse
import json
import os
from pathlib import Path
import platform
import shutil
import subprocess
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
from provision import provision, sha256
from audit import audit
from archive import canonical_archive

TARGET = 'x86_64-pc-windows-msvc'


def run(argv, env, cwd, capture=False):
    print('+ ' + subprocess.list2cmdline([str(x) for x in argv]), flush=True)
    return subprocess.run([str(x) for x in argv], env=env, cwd=cwd, check=True,
                          text=True, stdout=subprocess.PIPE if capture else None).stdout


def build(root, work, cache):
    root, work, cache = root.resolve(), work.resolve(), cache.resolve()
    if work.exists():
        raise ValueError(f'Build directory must be fresh: {work}')
    work.mkdir(parents=True)
    build_native(root, work, cache)


def build_native(root, work, cache):
    for parent in [work, *work.parents]:
        if any((parent / '.cargo' / name).exists() for name in ['config', 'config.toml']):
            raise ValueError(f'Unexpected ambient Cargo configuration in {parent}')
    provision(work / 'tools', cache)
    tools = work / 'tools'
    vc = tools / 'vs/VC/Tools/MSVC/14.44.35207'
    binary = vc / 'bin/Hostx64/x64'
    sdk = tools / 'sdk'
    sdk_version = '10.0.22621.0'
    system = Path(os.environ['SystemRoot'])
    git = shutil.which('git')
    if not git:
        raise ValueError('Git is required to fetch locked Cargo dependencies')
    # Allow only OS essentials; caller compiler/Cargo flags and developer shells
    # must not select different native inputs.
    env = {key: value for key, value in os.environ.items() if key.upper() in {
        'SYSTEMROOT', 'WINDIR', 'COMSPEC', 'SYSTEMDRIVE', 'USERPROFILE',
        'APPDATA', 'LOCALAPPDATA', 'PROGRAMDATA', 'PROGRAMFILES',
        'PROGRAMFILES(X86)', 'PROGRAMW6432',
    }}
    rust = tools / 'rust/bin'
    target = work / 'target'
    cargo_home = work / 'cargo'
    temporary = work / 'tmp'
    temporary.mkdir()
    env.update({
        'PATH': os.pathsep.join(str(p) for p in [binary, sdk / f'bin/{sdk_version}/x64',
            tools / 'cmake/cmake-3.31.8-windows-x86_64/bin', tools / 'protoc/bin',
            rust, Path(git).parent, system / 'System32', system]),
        'INCLUDE': os.pathsep.join(str(p) for p in [vc / 'include',
            sdk / f'Include/{sdk_version}/ucrt', sdk / f'Include/{sdk_version}/shared',
            sdk / f'Include/{sdk_version}/um', sdk / f'Include/{sdk_version}/winrt']),
        'LIB': os.pathsep.join(str(p) for p in [vc / 'lib/x64',
            sdk / f'Lib/{sdk_version}/ucrt/x64', sdk / f'Lib/{sdk_version}/um/x64']),
        'VCToolsInstallDir': str(vc) + os.sep,
        'VCINSTALLDIR': str(tools / 'vs/VC') + os.sep,
        'WindowsSdkDir': str(sdk) + os.sep, 'WindowsSDKVersion': sdk_version + os.sep,
        'VSCMD_ARG_TGT_ARCH': 'x64', 'VSCMD_ARG_HOST_ARCH': 'x64',
        'CC': str(binary / 'cl.exe'), 'CXX': str(binary / 'cl.exe'),
        'AR': str(binary / 'lib.exe'),
        'CARGO_TARGET_X86_64_PC_WINDOWS_MSVC_LINKER': str(binary / 'link.exe'),
        'PROTOC': str(tools / 'protoc/bin/protoc.exe'),
        'PROTOC_INCLUDE': str(tools / 'protoc/include'),
        'CARGO_HOME': str(cargo_home), 'CARGO_TARGET_DIR': str(target),
        'CARGO_INCREMENTAL': '0', 'CARGO_PROFILE_RELEASE_DEBUG': 'false',
        'CARGO_PROFILE_RELEASE_CODEGEN_UNITS': '16',
        'CARGO_PROFILE_RELEASE_LTO': 'false', 'CARGO_BUILD_JOBS': '8',
        'SOURCE_DATE_EPOCH': '1757635200', 'TZ': 'UTC', 'VSLANG': '1033',
        'TEMP': str(temporary), 'TMP': str(temporary),
        'GIT_CONFIG_NOSYSTEM': '1', 'GIT_CONFIG_GLOBAL': os.devnull,
        'GIT_CONFIG_COUNT': '2', 'GIT_CONFIG_KEY_0': 'core.autocrlf',
        'GIT_CONFIG_VALUE_0': 'false', 'GIT_CONFIG_KEY_1': 'core.longpaths',
        'GIT_CONFIG_VALUE_1': 'true',
    })
    mappings = [(root, '/mwc/source'), (work, '/mwc/build'),
                (rust.parent, '/mwc/rust')]
    rustflags = ['-C', 'link-arg=/Brepro', '-C', 'link-arg=/INCREMENTAL:NO',
                 '-C', 'link-arg=/DEBUG:NONE']
    for source, destination in mappings:
        for spelling in dict.fromkeys([str(source), source.as_posix()]):
            rustflags.append(f'--remap-path-prefix={spelling}={destination}')
    env['CARGO_ENCODED_RUSTFLAGS'] = '\x1f'.join(rustflags)
    cflags = ['/Brepro', '/experimental:deterministic']
    for source, destination in mappings:
        cflags.append(f'/pathmap:{source}={destination}')
    # Let cl parse its own quoted flags; cc crate's CFLAGS tokenization varies
    # across dependency versions and can split /pathmap arguments with spaces.
    env['CL'] = subprocess.list2cmdline(cflags)
    env['ARFLAGS'] = '/Brepro'
    (work / 'environment.json').write_text(json.dumps(env, indent=2) + '\n')
    cargo = rust / 'cargo.exe'
    manifest = root / 'rust/Cargo.toml'
    lock_before = sha256(root / 'rust/Cargo.lock')
    run([cargo, 'fetch', '--locked', '--manifest-path', manifest, '--target', TARGET], env, work)
    run([cargo, 'build', '--frozen', '--release', '--lib', '--manifest-path', manifest,
         '--target', TARGET], env, work)
    if sha256(root / 'rust/Cargo.lock') != lock_before:
        raise ValueError('Cargo.lock changed')
    release = target / TARGET / 'release'
    archive_evidence = canonical_archive(release / 'mwc_wallet.lib', release / 'mwc_wallet.canonical.lib')
    (release / 'mwc_wallet.canonical.lib').replace(release / 'mwc_wallet.lib')
    consumer = work / 'static-smoke.exe'
    run([binary / 'cl.exe', '/nologo', '/MD', '/O2',
         root / 'reproducible/windows/static-smoke.c',
         '/Fe:' + str(consumer), '/Fo:' + str(work / 'static-smoke.obj'),
         '/link', release / 'mwc_wallet.lib',
         *[name + '.lib' for name in (
             'advapi32 bcrypt crypt32 dbghelp dnsapi gdi32 iphlpapi kernel32 '
             'ncrypt netapi32 ntdll ole32 oleaut32 pdh powrprof propsys psapi '
             'secur32 shell32 user32 userenv version ws2_32').split()]], env, work)
    run([consumer], env, work)
    archive_evidence['static_consumer_passed'] = True
    inventory = {
        'target': TARGET, 'rust_version': run([rust / 'rustc.exe', '-vV'], env, work, True),
        'host': platform.platform(), 'python_version': platform.python_version(),
        'git_version': run([git, '--version'], env, root, True).strip(),
        'archive': archive_evidence,
        'tools_lock_sha256': sha256(tools / 'tools.lock.json'),
        'cargo_lock_sha256': lock_before,
        'artifacts': {name: sha256(release / name) for name in ['mwc_wallet.dll', 'mwc_wallet.lib']},
        'tool_hashes': {str(p.relative_to(tools)): sha256(p) for p in
            [binary / 'cl.exe', binary / 'link.exe', binary / 'lib.exe',
             rust / 'rustc.exe', rust / 'cargo.exe',
             tools / 'protoc/bin/protoc.exe',
             tools / 'cmake/cmake-3.31.8-windows-x86_64/bin/cmake.exe']},
    }
    reports = {}
    for option in ['/headers', '/dependents', '/exports']:
        report = run([binary / 'dumpbin.exe', option, release / 'mwc_wallet.dll'], env, work, True)
        (work / (option[1:] + '.txt')).write_text(report)
        reports[option[1:]] = report
    inventory['audit'] = audit(release / 'mwc_wallet.dll', release / 'mwc_wallet.lib', **reports)
    (work / 'build-evidence.json').write_text(json.dumps(inventory, indent=2) + '\n')
    print(json.dumps(inventory, indent=2))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=Path(__file__).resolve().parents[2])
    parser.add_argument('--work', type=Path, required=True)
    parser.add_argument('--cache', type=Path, required=True)
    args = parser.parse_args()
    build(args.root, args.work, args.cache)
