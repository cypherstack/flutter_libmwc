#!/usr/bin/env bash
set -euo pipefail

flake_ref="${1:-.#mwc-wallet}"

nix build "$flake_ref" --no-link
nix build "$flake_ref" --no-link --rebuild

output_path="$(nix path-info "$flake_ref")"
sha256sum "$output_path/lib/libmwc_wallet.so"
