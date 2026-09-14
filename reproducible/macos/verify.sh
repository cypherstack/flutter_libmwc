#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
args=(--no-link --no-update-lock-file --cores "${NIX_BUILD_CORES:-8}" --max-jobs 2)
derivation=$(nix path-info --derivation .#native-macos)
nix build "$derivation^out" "${args[@]}" -L
# The Darwin sandbox allocates a fresh temporary root for the second compile.
nix build "$derivation^out" "${args[@]}" --rebuild -L
output=$(nix path-info "$derivation^out")
(cd "$output/lib" && shasum -a 256 libmwc_wallet.a libmwc_wallet.dylib)
printf 'Clean rebuild matched: %s\n' "$output"
