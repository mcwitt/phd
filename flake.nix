{
  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
  inputs.git-hooks.url = "github:cachix/git-hooks.nix";

  outputs =
    {
      self,
      git-hooks,
      nixpkgs,
    }:
    let
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];

      forAllSystems =
        f:
        nixpkgs.lib.genAttrs supportedSystems (
          system:
          let
            pkgs = nixpkgs.legacyPackages.${system};
          in
          f system pkgs
        );
    in
    {

      packages = forAllSystems (
        _: pkgs: {
          default = pkgs.stdenv.mkDerivation {
            name = "thesis";

            src = builtins.path {
              path = ./.;
              name = "source";
            };

            nativeBuildInputs =
              let
                texlive = pkgs.texlive.withPackages (
                  ps: with ps; [
                    scheme-small

                    algorithmicx
                    algorithms
                    biblatex
                    cleveref
                    commath
                    pgfplots
                    siunitx
                    standalone
                    svn-prov
                    ucbthesis

                    biber
                    latexmk
                  ]
                );
              in
              [
                texlive
                pkgs.gnuplot
              ];

            buildPhase = ''
              export HOME=$(mktemp -d) # work around same symptom as https://github.com/NixOS/nixpkgs/pull/83816
              latexmk -e '$pdflatex=q/pdflatex %O -shell-escape %S/' -pdf main.tex
            '';

            installPhase = ''
              mv main.pdf $out
            '';
          };
        }
      );

      checks = forAllSystems (
        system: _: {
          pre-commit-check = git-hooks.lib.${system}.run {
            src = ./.;
            hooks = {
              nixfmt-rfc-style.enable = true;
            };
          };
        }
      );

      devShells = forAllSystems (
        system: pkgs: {
          default = pkgs.mkShell {
            inputsFrom = [ self.packages.${system}.default ];
            inherit (self.checks.${system}.pre-commit-check) shellHook;
            packages = self.checks.${system}.pre-commit-check.enabledPackages;
          };
        }
      );
    };
}
