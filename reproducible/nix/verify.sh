#!/usr/bin/env bash
# --rebuild forces execution even when the first result is already in the store.
set -euo pipefail
cd "$(dirname "$0")/../.."
args=(--no-link --no-update-lock-file --cores "${NIX_BUILD_CORES:-8}" --max-jobs 2)
derivation=$(nix path-info --derivation .#native-linux)
nix build "$derivation^out" "${args[@]}" -L
nix build "$derivation^out" "${args[@]}" --rebuild -L
output=$(nix path-info "$derivation^out")
(cd "$output/lib" && sha256sum libmwc_wallet.a libmwc_wallet.so)
printf 'Clean rebuild matched: %s\n' "$output"
