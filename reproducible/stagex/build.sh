#!/usr/bin/env bash
# Nix prepares a hash-checked vendor tree; StageX performs the offline compile.
set -euo pipefail
cd "$(dirname "$0")/../.."
output=${1:-build/stagex-musl}
if [ -e "$output" ]; then
  echo "Refusing to overwrite $output" >&2
  exit 1
fi
vendor=$(nix build .#cargo-vendor --no-link --print-out-paths --no-update-lock-file)
context=$(mktemp -d)
trap 'chmod -R u+w "$context"; rm -r "$context"' EXIT
cp -R "$vendor" "$context/vendor"
mkdir "$context/rust"
cp rust/Cargo.toml rust/Cargo.lock rust/rust-toolchain.toml "$context/rust/"
cp -R rust/src "$context/rust/src"
cp reproducible/smoke.c "$context/smoke.c"
docker buildx build --platform linux/amd64 --no-cache --network=none \
  --file reproducible/stagex/Containerfile \
  --output "type=local,dest=$output" "$context"
