#!/usr/bin/env bash
# Build the iOS Simulator (arm64) slice of libmwc_wallet and package it
# together with the existing device slice (ios/libs/libmwc_wallet.a,
# produced by build_all.sh or download.sh) into an XCFramework.
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

DEVICE_LIB="${PLUGIN_ROOT}/ios/libs/libmwc_wallet.a"
if [ ! -f "${DEVICE_LIB}" ]; then
    echo "Error: ${DEVICE_LIB} not found."
    echo "Run scripts/ios/build_all.sh or scripts/ios/download.sh first to produce the device slice."
    exit 1
fi

mkdir -p "${SCRIPT_DIR}/build"
echo ''$(git log -1 --pretty=format:"%H")' '$(date) >> "${SCRIPT_DIR}/build/git_commit_version.txt"

VERSIONS_FILE="${PLUGIN_ROOT}/lib/git_versions.dart"
EXAMPLE_VERSIONS_FILE="${PLUGIN_ROOT}/lib/git_versions_example.dart"
if [ ! -f "$VERSIONS_FILE" ]; then
    cp "$EXAMPLE_VERSIONS_FILE" "$VERSIONS_FILE"
fi
COMMIT=$(git log -1 --pretty=format:"%H")
OS="IOS"
sed -i '' '/\/\*${OS}_VERSION/c\'$'\n''/\*${OS}_VERSION\*\/ const ${OS}_VERSION = "'"$COMMIT"'";' "$VERSIONS_FILE"

# Copy the rust sources next to this script the same way build_all.sh does.
rm -rf "${SCRIPT_DIR}/build/rust"
cp -r "${PLUGIN_ROOT}/rust" "${SCRIPT_DIR}/build/rust"
cd "${SCRIPT_DIR}/build/rust"

rustup target add aarch64-apple-ios-sim

# some people need this apparently
export PROTOC=/opt/homebrew/bin/protoc

export IPHONEOS_DEPLOYMENT_TARGET=15.0
export CARGO_TARGET_AARCH64_APPLE_IOS_SIM_RUSTFLAGS="-C link-arg=-mios-simulator-version-min=15.0"
cargo build --release --target aarch64-apple-ios-sim

SIM_LIB="target/aarch64-apple-ios-sim/release/libmwc_wallet.a"

# Package device + simulator slices as an XCFramework (both are arm64, so
# lipo cannot combine them).
rm -rf "${PLUGIN_ROOT}/ios/libs/mwc_wallet.xcframework"
xcodebuild -create-xcframework \
    -library "${DEVICE_LIB}" -headers "${PLUGIN_ROOT}/ios/include" \
    -library "${SIM_LIB}" -headers "${PLUGIN_ROOT}/ios/include" \
    -output "${PLUGIN_ROOT}/ios/libs/mwc_wallet.xcframework"

echo "Done: ${PLUGIN_ROOT}/ios/libs/mwc_wallet.xcframework"
