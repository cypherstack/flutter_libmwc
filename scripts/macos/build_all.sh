#!/usr/bin/env bash
set -e
rm -rf build
mkdir build
echo ''$(git log -1 --pretty=format:"%H")' '$(date) >> build/git_commit_version.txt
VERSIONS_FILE=../../lib/git_versions.dart
EXAMPLE_VERSIONS_FILE=../../lib/git_versions_example.dart
if [ ! -f "$VERSIONS_FILE" ]; then
    cp $EXAMPLE_VERSIONS_FILE $VERSIONS_FILE
fi
COMMIT=$(git log -1 --pretty=format:"%H")
OSX="OSX"
sed -i '' '/\/\*${OS}_VERSION/c\'$'\n''/\*${OS}_VERSION\*\/ const ${OS}_VERSION = "'"$COMMIT"'";' "$VERSIONS_FILE"
cp -r ../../rust build/rust
cd build/rust

# some people need this apparently
export PROTOC=/opt/homebrew/bin/protoc

# building
cbindgen src/lib.rs -l c > libmwc_wallet.h
cargo lipo --release --targets aarch64-apple-darwin

xcodebuild -create-xcframework \
  -library target/aarch64-apple-darwin/release/libmwc_wallet.a \
  -headers libmwc_wallet.h \
  -output ../MWCWallet.xcframework

# moving files to the macos project
fwk=../../../../macos/framework/
rm -rf ${fwk}
mkdir ${fwk}
mv ../MWCWallet.xcframework ${fwk}
