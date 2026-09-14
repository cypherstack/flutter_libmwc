#!/usr/bin/env bash
# Run against the advertised glibc 2.35 floor with no /nix mount or network.
set -euo pipefail
cd "$(dirname "$0")/../.."
nix build .#native-linux .#smoke-linux --no-link --no-update-lock-file
library=$(nix path-info .#native-linux)
smoke=$(nix path-info .#smoke-linux)
docker run --rm --network=none --platform linux/amd64 \
  --mount "type=bind,src=$library/lib,dst=/prebuilt,readonly" \
  --mount "type=bind,src=$smoke/bin,dst=/smoke,readonly" \
  ubuntu@sha256:281c5745f657873d78e5531fc5ba8575f46ab7769b94550ac99543f122679986 \
  /smoke/mwc-native-smoke /prebuilt/libmwc_wallet.so
