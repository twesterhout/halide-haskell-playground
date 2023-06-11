{
  description = "A halide-haskell template project";

  nixConfig = {
    extra-experimental-features = "nix-command flakes";
    extra-substituters = "https://halide-haskell.cachix.org";
    extra-trusted-public-keys = "halide-haskell.cachix.org-1:cFPqtShCsH4aNjn2q4PHb39Omtd/FWRhrkTBcSrtNKQ=";
    allow-import-from-derivation = true;
  };

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/haskell-updates";
    flake-utils.url = "github:numtide/flake-utils";
    nix-filter.url = "github:numtide/nix-filter";
    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };
  };

  outputs = inputs: inputs.flake-utils.lib.eachDefaultSystem
    (system:
      with builtins;
      let
        pkgs = import inputs.nixpkgs { inherit system; };

        # Only consider source dirs and .cabal files as the source to our Haskell package.
        # This allows the project to rebuild only when the source files change.
        src = inputs.nix-filter.lib {
          root = ./.;
          include = [
            "src"
            "test"
            (inputs.nix-filter.lib.matchExt "cabal")
            "README.md"
            "LICENSE"
          ];
        };

        ghcVersion = "928";
        haskellPackages = pkgs.haskell.packages."ghc${ghcVersion}".override {
          overrides = self: suprt: {
            halide-haskell-playground =
              (self.callCabal2nix "halide-haskell-playground" src { });
          };
        };

      in
      {
        packages.default = haskellPackages.halide-haskell-playground;
        devShells.default = haskellPackages.shellFor {
          packages = ps: with ps; [
            halide-haskell-playground
          ];
          withHoogle = true;
          nativeBuildInputs = with pkgs; with haskellPackages; [
            # Building and testing
            cabal-install
            # Language servers
            haskell-language-server
            nil
            # Formatters
            fourmolu
            cabal-fmt
            nixpkgs-fmt
          ];
        };
        # The formatter to use for .nix files (but not .hs files)
        # Allows us to run `nix fmt` to reformat nix files.
        formatter = pkgs.nixpkgs-fmt;
      })
  // {
    templates.default = {
      path = ./.;
      description = "Minimal Haskell project with halide-haskell";
    };
  };
}
