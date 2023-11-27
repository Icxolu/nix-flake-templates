{
  description = "a collection of nix flake templates";

  outputs = {...}: {
    templates = {
      rust = {
        path = ./rust;
        description = "stable Rust toolchain for windows cross compilation";
      };
    };
  };
}
