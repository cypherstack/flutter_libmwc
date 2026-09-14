#!/usr/bin/env python3
"""Record GitHub run provenance and compare extracted CI payloads, not ZIP files."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import subprocess
import sys


def sha256(path):
    digest = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            digest.update(block)
    return digest.hexdigest()


def regular(root, name):
    if not isinstance(name, str) or not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9_.-]*', name):
        raise ValueError(f'Unsafe artifact name: {name!r}')
    path = root / name
    if path.is_symlink() or not path.is_file():
        raise ValueError(f'Missing or nonregular artifact: {path}')
    return path


def payload(root):
    manifest_path = regular(root, 'manifest.json')
    manifest = json.loads(manifest_path.read_text())
    if manifest.get('schema_version') != 1 or manifest.get('package') != 'flutter_libmwc':
        raise ValueError('Unsupported release manifest')
    if not re.fullmatch(r'[0-9a-f]{64}', manifest.get('source_sha256', '')):
        raise ValueError('Invalid source fingerprint')
    manifest_hash = sha256(manifest_path)
    pin = regular(root, 'manifest.sha256')
    if pin.read_text().split() != [manifest_hash, 'manifest.json']:
        raise ValueError('Manifest pin mismatch')
    hashes = {'manifest.json': manifest_hash, 'manifest.sha256': sha256(pin)}
    pairs = set()
    artifacts = manifest.get('artifacts')
    if not isinstance(artifacts, list) or not artifacts:
        raise ValueError('Empty release manifest')
    for artifact in artifacts:
        name = artifact['file']
        pair = (artifact['target'], artifact['link_mode'])
        if pair in pairs or name in hashes or pair[1] not in ('static', 'dynamic'):
            raise ValueError('Duplicate artifact or invalid link mode')
        pairs.add(pair)
        path = regular(root, name)
        actual = sha256(path)
        if path.stat().st_size != artifact['size'] or actual != artifact['sha256']:
            raise ValueError(f'Artifact hash/size mismatch: {name}')
        hashes[name] = actual
    for target, _ in pairs:
        if not all((target, mode) in pairs for mode in ('static', 'dynamic')):
            raise ValueError(f'Missing link mode for {target}')
    return {'source_sha256': manifest['source_sha256'], 'files': hashes}


def evidence(root, commit, repository, run_id, run_attempt):
    result = payload(root)
    recorded = json.loads(regular(root, 'ci-evidence.json').read_text())
    expected = {'schema_version': 1, 'source_commit': commit,
                'repository': repository, 'run_id': str(run_id),
                'run_attempt': str(run_attempt), **result}
    for key, value in expected.items():
        if recorded.get(key) != value:
            raise ValueError(f'CI provenance mismatch: {key}')
    return recorded


def compare(ci, other, commit, repository, run_id, run_attempt, ci_pair=False):
    first = evidence(ci, commit, repository, run_id, run_attempt)
    second = (evidence(other, commit, repository, run_id, run_attempt)
              if ci_pair else payload(other))
    for field in ('source_sha256', 'files'):
        if first[field] != second[field]:
            raise ValueError(f'Builds differ: {field}')
    return {'status': 'match', 'comparison': 'ci-to-ci' if ci_pair else 'local-to-ci',
            'source_commit': commit, 'repository': repository, 'run_id': str(run_id),
            'run_attempt': str(run_attempt), 'ci_runner': first['runner'],
            'other_runner': second.get('runner', platform.platform()),
            'source_sha256': first['source_sha256'], 'files': first['files']}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest='command', required=True)
    record = commands.add_parser('record', help='Record provenance inside GitHub Actions')
    record.add_argument('directory', type=Path)
    record.add_argument('--runner', required=True)
    check = commands.add_parser('compare', help='Compare downloaded CI output with local or CI output')
    check.add_argument('ci_directory', type=Path)
    check.add_argument('other_directory', type=Path)
    check.add_argument('--commit', required=True)
    check.add_argument('--repository', required=True)
    check.add_argument('--run-id', required=True)
    check.add_argument('--run-attempt', required=True)
    check.add_argument('--ci-pair', action='store_true')
    args = parser.parse_args()
    if args.command == 'record':
        if os.environ.get('GITHUB_ACTIONS') != 'true':
            raise ValueError('Run provenance must be recorded inside GitHub Actions')
        commit = subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip()
        if commit != os.environ['GITHUB_SHA']:
            raise ValueError('Checkout does not match GITHUB_SHA')
        result = {'schema_version': 1, 'source_commit': commit,
                  'repository': os.environ['GITHUB_REPOSITORY'],
                  'run_id': os.environ['GITHUB_RUN_ID'],
                  'run_attempt': os.environ['GITHUB_RUN_ATTEMPT'],
                  'workflow_ref': os.environ['GITHUB_WORKFLOW_REF'],
                  'workflow_sha': os.environ['GITHUB_WORKFLOW_SHA'],
                  'runner': args.runner, 'runner_image_version': os.environ.get('ImageVersion'),
                  **payload(args.directory)}
        with (args.directory / 'ci-evidence.json').open('x') as stream:
            json.dump(result, stream, indent=2, sort_keys=True)
            stream.write('\n')
    else:
        if not re.fullmatch(r'[0-9a-f]{40}', args.commit):
            raise ValueError('Supply a full 40-character commit SHA')
        if not args.ci_pair:
            commit = subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip()
            if commit != args.commit:
                raise ValueError('Check out the exact GitHub run commit before comparing')
            status = subprocess.check_output(['git', 'status', '--porcelain', '--untracked-files=all'], text=True)
            if status.strip():
                raise ValueError('Use a clean checkout for the local comparison')
        result = compare(args.ci_directory, args.other_directory, args.commit,
                         args.repository, args.run_id, args.run_attempt, args.ci_pair)
    print(json.dumps(result, indent=2, sort_keys=True))


if __name__ == '__main__':
    try:
        main()
    except (ValueError, KeyError, OSError, subprocess.CalledProcessError) as error:
        sys.exit(f'CI artifact verification failed: {error}')
