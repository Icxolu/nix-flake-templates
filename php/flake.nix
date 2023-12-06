{
  description = "PHP dev shell";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.11";

    phps.url = "github:fossar/nix-phps";
    phps.inputs.nixpkgs.follows = "nixpkgs";
    phps.inputs.flake-compat.follows = "devenv/flake-compat";
    phps.inputs.utils.follows = "devenv/pre-commit-hooks/flake-utils";
    # https://github.com/cachix/devenv/issues/756
    devenv.url = "github:cachix/devenv/9ba9e3b908a12ddc6c43f88c52f2bf3c1d1e82c1";
    devenv.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = {
    self,
    nixpkgs,
    phps,
    devenv,
    ...
  } @ inputs: let
    pkgs = nixpkgs.legacyPackages."x86_64-linux";
  in {
    devShell.x86_64-linux = devenv.lib.mkShell {
      inherit inputs pkgs;
      modules = [
        ({
          pkgs,
          config,
          ...
        }: {
          # This is your devenv configuration
          packages = with pkgs; [
            phps.packages.x86_64-linux.php74
            phps.packages.x86_64-linux.php74.packages.composer
            symfony-cli
          ];

          enterShell = ''
            devenv up &
            DEVENV_PID=$!

            function finish {
              kill $DEVENV_PID
            }
            trap finish EXIT

          '';

          services.mysql = {
            enable = true;
            package = pkgs.mariadb;
            initialDatabases = [{name = "symfony";}];
            ensureUsers = [
              {
                name = "symfony";
                password = "symfony";
                ensurePermissions = {
                  "*.*" = "ALL PRIVILEGES";
                };
              }
            ];
          };
        })
      ];
    };
  };
}
