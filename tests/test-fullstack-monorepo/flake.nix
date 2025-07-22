{
  description = "Test full-stack monorepo for backend implementation";

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
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            nodejs_18
            npm-check-updates
            nodePackages.npm
            # Rust toolchain
            rustc
            cargo
            rustfmt
            clippy
          ];
          
          shellHook = ''
            echo "Full-stack development environment loaded"
            echo "Frontend: Node.js $(node --version)"
            echo "Backend: Rust $(rustc --version)"
          '';
        };
      });
}
