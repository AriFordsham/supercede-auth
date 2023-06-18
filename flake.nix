{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      with nixpkgs.legacyPackages.${system};
      let
        t = lib.trivial;
        hl = haskell.lib;

        name = "supercede-auth";

        project = devTools:
          let addBuildTools = (t.flip hl.addBuildTools) devTools;
          in haskellPackages.developPackage {
            root = lib.sourceFilesBySuffices ./. [ ".cabal" ".hs" ];
            name = name;
            returnShellEnv = !(devTools == [ ]);

            modifier = (t.flip t.pipe) [
              addBuildTools
              hl.dontHaddock
              hl.enableStaticLibraries
              hl.justStaticExecutables
              hl.disableLibraryProfiling
              hl.disableExecutableProfiling
            ];

            overrides = self: super: {
              yesod-auth-simple =
                self.callCabal2nix "yesod-auth-simple" (builtins.fetchGit {
                     url = "https://github.com/SupercedeTech/yesod-auth-simple";
                     rev = "eece011c4ad9abef545bfbc0816a09f41ae6d03e";
                  }) {};

              yesod-autoreload =
                self.callCabal2nix "yesod-autoreload" (builtins.fetchGit {
                     url = "https://github.com/NorfairKing/yesod-autoreload";
                     rev = "6901d54fc68cf6bf19d8b5af36874488141414a6";
                  }) {};
            };
          };

      in {
        packages.pkg = project [ ];

        defaultPackage = self.packages.${system}.pkg;

        devShell = project (with haskellPackages; [
          cabal-fmt
          cabal-install
          haskell-language-server
          hlint
        ]);
      });
}
