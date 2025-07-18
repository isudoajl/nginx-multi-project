{
  description = "Test monorepo for nginx-multi-project validation";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        packages = {
          frontend = pkgs.stdenv.mkDerivation {
            name = "test-frontend";
            src = ./frontend;
            buildInputs = with pkgs; [ nodejs nodePackages.npm ];
            buildPhase = ''
              npm install
              npm run build
            '';
            installPhase = ''
              mkdir -p $out/dist
              cp -r dist/* $out/dist/
            '';
          };
        };

        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            nodejs
            nodePackages.npm
          ];
        };
      });
}
