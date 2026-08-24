# StageX build

This is a StageX `user` package definition for the native Linux MWC library.
It targets StageX commit `9bdf430d09ce2ba53932df0182faef00d4feecd1`;
`stagex.lock` records the expected amd64 dependency-image digests.

Copy this directory to `packages/user/stack-wallet-mwc` in a checkout of that
StageX revision, add it to the Git index, then run:

```sh
make fetch PKG=stack-wallet-mwc
make user-stack-wallet-mwc NOCACHE=1
python3 src/package-digests.py user-stack-wallet-mwc
```

The plugin archive is SHA-256 locked, Cargo resolves its crates and Git
dependencies from `Cargo.lock`, and compilation runs offline. The three
mutable patch entries removed before fetching are explicitly marked unused by
the lock file. Reproduce independently and compare the image digest.
