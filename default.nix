{
  pkgs ? import <nixpkgs> { },
}:

# Legacy compatibility for non-flake usage
# This allows building with `nix-build` without flakes

let
  # Import the flake outputs
  flake = import ./flake.nix;

  # Get the system's current system
  system = pkgs.system;

  # Import the flake outputs for this system
  flakeOutputs = flake {
    inherit pkgs;
    system = system;
  };

in
{
  # Hydra-Pool package
  hydrapool = flakeOutputs.packages.hydrapool;

  # Start9 package
  start9 = flakeOutputs.packages.start9;

  # Docker image
  docker = flakeOutputs.packages.docker;

  # Development shell
  shell = flakeOutputs.devShells.default;

  # NixOS module
  nixosModule = flakeOutputs.nixosModules.default;
}
