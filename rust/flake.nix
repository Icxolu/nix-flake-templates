{
  description = "Rust dev shell for windows cross compiling";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    rust-overlay.url = "github:oxalica/rust-overlay";
    rust-overlay.inputs.flake-utils.follows = "flake-utils";
    rust-overlay.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = {
    self,
    nixpkgs,
    rust-overlay,
    flake-utils,
    ...
  }:
    flake-utils.lib.eachDefaultSystem (
      system: let
        overlays = [(import rust-overlay)];
        crossSystem = {config = "x86_64-w64-mingw32";};
        pkgs = import nixpkgs {
          inherit system overlays crossSystem;
        };
      in {
        # Workaround: we need `callPackage` to enable auto package-splicing, thus we don't need to manually prefix
        # everything in `nativeBuildInputs` with `buildPackages.`.
        # See: https://github.com/NixOS/nixpkgs/issues/49526
        devShells.default = pkgs.callPackage (
          {
            mkShell,
            rust-bin,
            windows,
            pkg-config,
            openssl,
          }:
            mkShell {
              # Build-time dependencies. build = host = your-machine, target = aarch64
              # Typically contains,
              # - Configure-related: cmake, pkg-config
              # - Compiler-related: gcc, rustc, binutils
              # - Code generators run at build time: yacc, bision
              nativeBuildInputs = [
                rust-bin.stable.latest.default
                pkg-config
              ];
              # Run-time dependencies. build = your-matchine, host = target = aarch64
              # Usually are libraries to be linked.
              buildInputs = [
                openssl
                windows.pthreads
              ];
              # Build-time tools which are target agnostic. build = host = target = your-machine.
              # Emulaters should essentially also go `nativeBuildInputs`. But with some packaging issue,
              # currently it would cause some rebuild.
              # We put them here just for a workaround.
              # See: https://github.com/NixOS/nixpkgs/pull/146583
              depsBuildBuild = [];
            }
        ) {};
      }
    );
}
