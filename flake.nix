{
  description = "ratty — GPU-rendered terminal emulator with inline 3D";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    crane.url = "github:ipetkov/crane";
  };

  outputs = { self, nixpkgs, flake-utils, rust-overlay, crane }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ rust-overlay.overlays.default ];
        };

        rustToolchain = pkgs.rust-bin.stable.latest.default.override {
          extensions = [ "rust-src" "rust-analyzer" "clippy" "rustfmt" ];
        };

        craneLib = (crane.mkLib pkgs).overrideToolchain rustToolchain;

        src = pkgs.lib.cleanSourceWith {
          src = ./.;
          filter = path: type:
            (craneLib.filterCargoSources path type)
            || (builtins.match ".*/(assets|config|protocols)(/.*)?$" path != null);
        };

        nativeBuildInputs = with pkgs; [ pkg-config makeWrapper ];

        buildInputs = with pkgs; [
          alsa-lib
          fontconfig
          udev
          wayland
          libxkbcommon
          libxcb
          libx11
          libxcursor
          libxi
          libxrandr
          vulkan-loader
          libGL
        ];

        runtimeLibs = with pkgs; [
          vulkan-loader
          libGL
          wayland
          libxkbcommon
          libx11
          libxcursor
          libxi
          libxrandr
          fontconfig
          alsa-lib
          udev
        ];

        commonArgs = {
          inherit src nativeBuildInputs buildInputs;
          strictDeps = true;
        };

        cargoArtifacts = craneLib.buildDepsOnly commonArgs;

        ratty = craneLib.buildPackage (commonArgs // {
          inherit cargoArtifacts;
          postInstall = ''
            wrapProgram $out/bin/ratty \
              --prefix LD_LIBRARY_PATH : "${pkgs.lib.makeLibraryPath runtimeLibs}"
          '';
        });
      in
      {
        packages.default = ratty;
        apps.default = flake-utils.lib.mkApp { drv = ratty; };

        devShells.default = pkgs.mkShell {
          inputsFrom = [ ratty ];
          packages = [ rustToolchain pkgs.cargo-watch ];
          LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath runtimeLibs;
          RUST_SRC_PATH = "${rustToolchain}/lib/rustlib/src/rust/library";
        };

        formatter = pkgs.nixpkgs-fmt;
      });
}
