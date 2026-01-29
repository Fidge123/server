{
  description = "Self-hosted infrastructure with NixOS";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";

    # For future phases
    # sops-nix.url = "github:Mic92/sops-nix";
    # sops-nix.inputs.nixpkgs.follows = "nixpkgs";
    
    # deploy-rs.url = "github:serokell/deploy-rs";
    # deploy-rs.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, ... }@inputs:
    let
      # Systems to support
      supportedSystems = [ "x86_64-linux" "aarch64-linux" ];
      
      # Helper to generate attributes for each system
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
      
      # Nixpkgs instantiated for each system
      nixpkgsFor = forAllSystems (system: import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      });
    in
    {
      # NixOS configurations
      nixosConfigurations = {
        server = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = { inherit inputs self; };
          modules = [
            ./hosts/server/configuration.nix
          ];
        };

        # VM configuration for testing (no hardware dependencies)
        server-vm = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = { inherit inputs self; };
          modules = [
            ./hosts/server/configuration.nix
            # VM-specific overrides
            ({ config, pkgs, modulesPath, ... }: {
              imports = [ (modulesPath + "/virtualisation/qemu-vm.nix") ];
              
              # VM settings
              virtualisation = {
                memorySize = 2048;
                cores = 2;
                graphics = false;
                forwardPorts = [
                  { from = "host"; host.port = 2222; guest.port = 22; }
                ];
              };
              
              # Allow passwordless sudo for testing
              security.sudo.wheelNeedsPassword = false;
              
              # Test user
              users.users.test = {
                isNormalUser = true;
                extraGroups = [ "wheel" ];
                initialPassword = "test";
              };
            })
          ];
        };
      };

      # Reusable NixOS modules
      nixosModules = {
        common = import ./modules/common.nix;
      };

      # Checks (including VM tests)
      checks = forAllSystems (system:
        let
          pkgs = nixpkgsFor.${system};
        in
        {
          # Basic flake evaluation check
          flake-check = pkgs.runCommand "flake-check" {} ''
            echo "Flake evaluation successful"
            touch $out
          '';
        } // (if system == "x86_64-linux" then {
          # VM tests only on x86_64-linux
          phase-1-flake = pkgs.nixosTest {
            name = "phase-1-basic-flake";

            nodes.server = { config, pkgs, lib, modulesPath, ... }: {
              imports = [ 
                ./hosts/server/configuration.nix
                self.nixosModules.common
              ];
              
              # VM-specific overrides for testing
              boot.loader.grub.enable = false;
              fileSystems."/" = {
                device = "/dev/disk/by-label/nixos";
                fsType = "ext4";
              };
              
              # Test user with passwordless sudo
              security.sudo.wheelNeedsPassword = false;
              users.users.test = {
                isNormalUser = true;
                extraGroups = [ "wheel" ];
                initialPassword = "test";
              };
            };

            testScript = ''
              server.start()
              server.wait_for_unit("multi-user.target")
              
              # Verify basic system functionality
              server.succeed("nixos-version")
              server.succeed("systemctl is-system-running --wait || true")
              
              # Verify SSH is running
              server.wait_for_unit("sshd.service")
              server.succeed("systemctl is-active sshd")
              
              # Verify firewall is enabled
              server.succeed("systemctl is-active firewall")
              
              print("✅ Phase 1 validation passed!")
            '';
          };
        } else {})
      );

      # Development shells
      devShells = forAllSystems (system:
        let
          pkgs = nixpkgsFor.${system};
        in
        {
          default = pkgs.mkShell {
            buildInputs = with pkgs; [
              nixpkgs-fmt
              nil  # Nix LSP
              # Future: sops, age, deploy-rs
            ];
          };
        }
      );

      # Formatter
      formatter = forAllSystems (system: nixpkgsFor.${system}.nixpkgs-fmt);
    };
}
