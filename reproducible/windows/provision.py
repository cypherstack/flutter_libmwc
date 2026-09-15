"""Extract hash-pinned Microsoft tools and generators without a VS installation."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import tarfile
import tempfile
import urllib.request
import zipfile


def sha256(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def provision(destination, cache):
    if destination.exists():
        raise ValueError(f'Tool destination must be fresh: {destination}')
    cache.mkdir(parents=True, exist_ok=True)
    lock = Path(__file__).with_name('tools.lock.json').read_bytes()
    pins = json.loads(lock)
    for pin in pins:
        archive = cache / pin['archive']
        if not archive.exists() or sha256(archive) != pin['sha256']:
            print(f"Downloading {pin['id']}", flush=True)
            with tempfile.NamedTemporaryFile(dir=cache, prefix=pin['id'] + '-',
                                             suffix='.download', delete=False) as file:
                temporary = Path(file.name)
            try:
                urllib.request.urlretrieve(pin['url'], temporary)
                if sha256(temporary) != pin['sha256']:
                    raise ValueError(f"Download digest mismatch: {pin['id']}")
                temporary.replace(archive)
            finally:
                temporary.unlink(missing_ok=True)
        if sha256(archive) != pin['sha256']:
            raise ValueError(f"Cache digest mismatch: {pin['id']}")
        print(f"Extracting {pin['id']}", flush=True)
        if pin['kind'] == 'rust':
            with tarfile.open(archive) as source:
                for member in source:
                    parts = member.name.split('/', 2)
                    if len(parts) != 3 or not member.isfile():
                        continue
                    relative = parts[2]
                    if not relative.startswith(('bin/', 'lib/')):
                        continue
                    path = destination / 'rust' / relative
                    if not path.resolve().is_relative_to(destination.resolve()):
                        raise ValueError(f'Unsafe archive member: {member.name}')
                    path.parent.mkdir(parents=True, exist_ok=True)
                    with source.extractfile(member) as inp, path.open('wb') as out:
                        shutil.copyfileobj(inp, out)
            continue
        with zipfile.ZipFile(archive) as source:
            for member in source.infolist():
                name = member.filename.replace('\\', '/')
                kind = pin['kind']
                if kind == 'vsix':
                    if not name.startswith('Contents/'):
                        continue
                    relative = 'vs/' + name[len('Contents/'):]
                elif kind == 'sdk':
                    if not name.startswith(('c/Include/', 'c/bin/10.0.22621.0/x64/')):
                        continue
                    relative = 'sdk/' + name[2:]
                elif kind == 'sdk-x64':
                    if not name.startswith(('c/um/x64/', 'c/ucrt/x64/')):
                        continue
                    relative = 'sdk/Lib/10.0.22621.0/' + name[2:]
                else:
                    relative = kind + '/' + name
                path = destination / relative
                if not path.resolve().is_relative_to(destination.resolve()):
                    raise ValueError(f'Unsafe archive member: {name}')
                if member.is_dir():
                    continue
                path.parent.mkdir(parents=True, exist_ok=True)
                with source.open(member) as inp, path.open('wb') as out:
                    shutil.copyfileobj(inp, out)
    (destination / 'tools.lock.json').write_bytes(lock)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--destination', type=Path, required=True)
    parser.add_argument('--cache', type=Path, required=True)
    args = parser.parse_args()
    provision(args.destination, args.cache)
