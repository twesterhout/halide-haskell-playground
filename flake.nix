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
    nix-filter.url = "github:numtide/nix-filter";
  };

  outputs = inputs:
    let
      lib = inputs.nixpkgs.lib;
      foreach = xs: f: with lib; foldr recursiveUpdate { } (
        if isList xs then map f xs
        else if isAttrs xs then mapAttrsToList f xs
        else error "foreach: expected list or attrset"
      );
      nix-filter = inputs.nix-filter.lib;
      # Only consider source dirs and .cabal files as the source to our Haskell package.
      # This allows the project to rebuild only when the source files change.
      src = nix-filter {
        root = ./.;
        include = [
          "src"
          "test"
          (nix-filter.matchExt "cabal")
          "README.md"
          "LICENSE"
        ];
      };
      pname = "halide-haskell-playground";
    in
    with builtins;
    with lib;
    foreach inputs.nixpkgs.legacyPackages
      (system: pkgs:
        let
          haskellPackages = mapAttrs
            (_: ps: ps.override {
              overrides = self: super: {
                "${pname}" = self.callCabal2nix pname src { };
              };
            })
            ({ default = pkgs.haskellPackages; } // filterAttrs (name: _: match "ghc[0-9]+" name != null) pkgs.haskell.packages);
        in
        {
          packages.${system} = haskellPackages // {
            default = haskellPackages.default.${pname};
          };
          devShells.${system} = mapAttrs
            (_: ps: ps.shellFor {
              packages = _: [ ps.${pname} ];
              withHoogle = true;
              nativeBuildInputs = with pkgs; with ps; [
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
            })
            haskellPackages;
          formatter.${system} = pkgs.nixpkgs-fmt;
        }
      )
    //
    {
      templates.default = {
        path = ./.;
        description = "Minimal Haskell project with halide-haskell";
      };
    };
}
