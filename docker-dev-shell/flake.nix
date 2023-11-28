{
  description = "a docker/oci container with a rust dev shell";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    rust-overlay.url = "github:oxalica/rust-overlay";
    rust-overlay.inputs.flake-utils.follows = "flake-utils";
    rust-overlay.inputs.nixpkgs.follows = "nixpkgs";
    msb.url = "github:rrbutani/nix-mk-shell-bin";
  };

  outputs = {
    self,
    nixpkgs,
    rust-overlay,
    flake-utils,
    msb,
    ...
  }:
    flake-utils.lib.eachDefaultSystem (
      system: let
        overlays = [(import rust-overlay)];
        crossSystem = {config = "armv7l-unknown-linux-gnueabihf";};
        pkgs = import nixpkgs {
          inherit
            system
            overlays
            ;
        };
        pkgsCross = import nixpkgs {
          inherit
            system
            overlays
            crossSystem
            ;
        };
        name = "rust-stable-armv7";

        # build a dev shell
        #
        # Workaround: we need `callPackage` to enable auto package-splicing, thus we don't need to manually prefix
        # everything in `nativeBuildInputs` with `buildPackages.`.
        # See: https://github.com/NixOS/nixpkgs/issues/49526
        shell = pkgsCross.callPackage (
          {
            mkShell,
            rust-bin,
            pkg-config,
            udev,
            git,
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
                udev
              ];
              # Build-time tools which are target agnostic. build = host = target = your-machine.
              depsBuildBuild = [
                git
              ];
            }
        ) {};

        # package dev shell into binary
        shellBin = msb.lib.mkShellBin {
          nixpkgs = pkgs;
          drv = shell;
          bashPrompt = "[${name}]$ ";
        };

        # create link to shell
        shLink = pkgs.runCommand "bin-sh" {} ''
          mkdir -p $out/bin
          ln -s ${shellBin}/bin/${shellBin.name} $out/bin/sh
        '';

        # build docker image
        dockerImage = pkgs.dockerTools.buildImage {
          inherit name;
          tag = "latest";
          copyToRoot = [shellBin shLink pkgs.dockerTools.caCertificates];
          extraCommands = ''
            mkdir -p -m 1777 tmp
          '';
          config = {
            Cmd = ["${shellBin}/bin/${shellBin.name}"];
          };
        };
      in {
        devShells.default = shell;
        packages.docker = dockerImage;
        packages.default = dockerImage;
      }
    );
}
