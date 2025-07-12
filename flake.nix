{
  description = "Microservices Nginx Architecture";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { 
          inherit system; 
          config = { allowUnfree = true; };
        };

        # Podman setup script
        podmanSetupScript = let
          registriesConf = pkgs.writeText "registries.conf" ''
            [registries.search]
            registries = ['docker.io']
            [registries.block]
            registries = []
          '';
        in pkgs.writeShellScriptBin "podman-setup" ''
          #!${pkgs.runtimeShell}
          # Don't overwrite customized configuration
          mkdir -p ~/.config/containers
          if ! test -f ~/.config/containers/policy.json; then
            install -Dm555 ${pkgs.skopeo.src}/default-policy.json ~/.config/containers/policy.json
          fi
          if ! test -f ~/.config/containers/registries.conf; then
            install -Dm555 ${registriesConf} ~/.config/containers/registries.conf
          fi
        '';

        # Podman capabilities setup script
        podmanCapabilitiesScript = pkgs.writeShellScriptBin "podman-capabilities" ''
          #!${pkgs.runtimeShell}
          
          # Set capabilities for rootless podman
          NEWUIDMAP=$(readlink --canonicalize $(which newuidmap))
          NEWGIDMAP=$(readlink --canonicalize $(which newgidmap))

          if ! ${pkgs.libcap}/bin/getcap "$NEWUIDMAP" | grep -q "cap_setuid+ep"; then
            echo 'Setting capabilities for podman rootless mode. This requires sudo:'
            sudo ${pkgs.libcap}/bin/setcap cap_setuid+ep "$NEWUIDMAP"
            sudo ${pkgs.libcap}/bin/setcap cap_setgid+ep "$NEWGIDMAP"
            sudo chmod -s "$NEWUIDMAP"
            sudo chmod -s "$NEWGIDMAP"
          else
            echo 'Podman rootless capabilities already set correctly.'
          fi
        '';

        # Docker compatibility layer
        dockerCompat = pkgs.runCommandNoCC "docker-podman-compat" {} ''
          mkdir -p $out/bin
          ln -s ${pkgs.podman}/bin/podman $out/bin/docker
        '';

        # Cleanup script
        podmanCleanupScript = pkgs.writeShellScriptBin "podman-cleanup" ''
          #!${pkgs.runtimeShell}
          
          echo "Cleaning up podman resources..."
          podman ps --all --quiet | xargs --no-run-if-empty podman stop
          podman ps --all --quiet | xargs --no-run-if-empty podman rm --force
          podman images --quiet | xargs --no-run-if-empty podman rmi --force
          podman container prune --force
          podman image prune --force
          podman network ls --quiet | xargs --no-run-if-empty podman network rm
          podman volume ls --quiet | xargs --no-run-if-empty podman volume prune
          echo "Podman cleanup completed."
        '';

      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            openssl
            nginx
            # Podman and dependencies
            podman
            conmon
            runc
            slirp4netns
            shadow
            # Custom scripts
            podmanSetupScript
            podmanCapabilitiesScript
            podmanCleanupScript
            dockerCompat
          ];

          shellHook = ''
            export IN_NIX_SHELL=1
            echo "Welcome to the Microservices Nginx Architecture development environment!"
            
            # Setup podman for rootless operation
            podman-setup
            podman-capabilities
            
            # Create the nginx-proxy network if it doesn't exist
            if ! podman network ls | grep -q "nginx-proxy-network"; then
              echo "Creating nginx-proxy network..."
              podman network create nginx-proxy-network
            fi
          '';
        };
      }
    );
} 