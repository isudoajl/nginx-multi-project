{
  description = "Microservices Nginx Architecture";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            openssl
            nginx
            podman
            docker
          ];

          shellHook = ''
            export IN_NIX_SHELL=1
            echo "Welcome to the Microservices Nginx Architecture development environment!"
          '';
        };
      }
    );
} 