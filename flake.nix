{
  description = "rutter-hs";

  inputs = {
    # Nix Inputs
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    rutter-openapi-spec.url = "https://production.rutterapi.com/openapi/specs/2023-03-14.yaml";
    rutter-openapi-spec.flake = false;
  };

  outputs = {
    self,
    nixpkgs,
    rutter-openapi-spec
  }: 
    let
      forAllSystems = function:
        nixpkgs.lib.genAttrs [
          "x86_64-linux"
          "aarch64-linux"
          "x86_64-darwin"
          "aarch64-darwin"
        ] (system: function rec {
          inherit system;
          compilerVersion = "ghc963";
          pkgs = nixpkgs.legacyPackages.${system};
          hsPkgs = pkgs.haskell.packages.${compilerVersion}.override {
            overrides = hfinal: hprev: {
              rutter-hs = hfinal.callCabal2nix "rutter-hs" ./generated-client {};
            };
          };
        });
    in
    {
      # nix fmt
      formatter = forAllSystems ({pkgs, ...}: pkgs.alejandra);

      # nix develop
      devShell = forAllSystems ({hsPkgs, pkgs, ...}:
        hsPkgs.shellFor {
          # withHoogle = true;
          packages = p: [
            p.rutter-hs
          ];
          buildInputs = with pkgs;
            [
              hsPkgs.haskell-language-server
              haskellPackages.cabal-install
              cabal2nix
              haskellPackages.ghcid
              haskellPackages.fourmolu
              haskellPackages.cabal-fmt
              openapi-generator-cli
            ];
        });

      # nix build
      packages = forAllSystems ({hsPkgs, pkgs, ...}: {
          rutter-hs = hsPkgs.rutter-hs;
          default = hsPkgs.rutter-hs;
          generate = (import ./generate.nix) { inherit pkgs rutter-openapi-spec; };
      });

      # You can't build the rutter-hs package as a check because of IFD in cabal2nix
      checks = {};

      # nix run
      apps = forAllSystems ({system, ...}: {
        rutter-hs = { 
          type = "app"; 
          program = "${self.packages.${system}.rutter-hs}/bin/rutter-hs"; 
        };
        generate = { 
          type = "app"; 
          program = "${self.packages.${system}.generate}/bin/generate"; 
        };
        default = self.apps.${system}.rutter-hs;
      });
    };
}
