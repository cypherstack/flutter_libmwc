{
  description = "Reproducible native builds for flutter_libmwc";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    rust-overlay.url = "github:oxalica/rust-overlay";
  };

  outputs = { self, nixpkgs, rust-overlay }:
    let
      supportedSystems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
    in {
      packages = forAllSystems (system:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [ (import rust-overlay) ];
          };
          rustToolchain = pkgs.rust-bin.stable."1.85.1".minimal;
          rustPlatform = pkgs.makeRustPlatform {
            cargo = rustToolchain;
            rustc = rustToolchain;
          };
        in {
          mwc-wallet = rustPlatform.buildRustPackage {
            pname = "mwc-wallet";
            version = "0.1.0";
            src = ./rust;
            cargoHash = "sha256-SJiYPbjjlwh+B0Ho5u3aubdMRQuI2vVgxtCj9yGvWcs=";

            nativeBuildInputs = with pkgs; [ cmake perl pkg-config protobuf_21 ];
            postPatch = ''
              # These two patches are explicitly recorded as unused in the
              # checked-in lock file. Removing them avoids asking Cargo's
              # offline vendor source for packages it correctly omitted.
              sed -i '/^mwc_config = { git = "https:\/\/github.com\/cypherstack\/mwc-node"/d' Cargo.toml
              sed -i '/^mwc_servers = { git = "https:\/\/github.com\/cypherstack\/mwc-node"/d' Cargo.toml
              sed -i '/^mwc-bitcoin = { git = "https:\/\/github.com\/cypherstack\/rust-bitcoin"/d' Cargo.toml
            '';
            cargoBuildFlags = [ "--lib" ];
            doCheck = false;

            env = {
              PROTOC = "${pkgs.protobuf_21}/bin/protoc";
              SOURCE_DATE_EPOCH = "1";
              RUSTFLAGS = "-C debuginfo=0 --remap-path-prefix=/build/source=.";
            };

            installPhase = ''
              runHook preInstall
              library="$(find target -name libmwc_wallet.so -print -quit)"
              test -n "$library"
              install -Dm755 "$library" "$out/lib/libmwc_wallet.so"
              runHook postInstall
            '';
          };

          default = self.packages.${system}.mwc-wallet;
        });

      checks = forAllSystems (system: {
        inherit (self.packages.${system}) mwc-wallet;
      });
    };
}
