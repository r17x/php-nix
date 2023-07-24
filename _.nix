{
  description = "My Nginx Flake";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }: {
    nixosConfigurations = {
      myNginxConfig = nixpkgs.lib.nixosSystem {
        system = "aarch64-darwin";
      };
    };
  };
}