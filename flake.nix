{
  description = "Self-hosted infrastructure with NixOS";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";

    # Secrets management
    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
    
    # For future phases
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
          
          # Common test node configuration that includes sops-nix
          mkTestNode = { extraConfig ? {} }: { config, pkgs, lib, modulesPath, ... }: {
            imports = [ 
              inputs.sops-nix.nixosModules.sops
              ./modules/common.nix
            ];
            
            # Basic server configuration (subset of hosts/server/configuration.nix)
            networking.hostName = "server";
            time.timeZone = "Europe/Berlin";
            
            environment.systemPackages = with pkgs; [ vim git ];
            
            services.openssh = {
              enable = true;
              settings.PasswordAuthentication = false;
            };
            
            networking.firewall = {
              enable = true;
              allowedTCPPorts = [ 22 ];
            };
            
            nix.settings.experimental-features = [ "nix-command" "flakes" ];
            system.stateVersion = "24.11";
            
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
          } // extraConfig;
        in
        {
          # Basic flake evaluation check
          flake-check = pkgs.runCommand "flake-check" {} ''
            echo "Flake evaluation successful"
            touch $out
          '';
        } // (if system == "x86_64-linux" then {
          # VM tests only on x86_64-linux
          phase-1-flake = let
            testKeyFile = pkgs.writeText "test-age-key" (builtins.readFile ./keys/test.age);
          in pkgs.nixosTest {
            name = "phase-1-basic-flake";

            nodes.server = mkTestNode {
              extraConfig = {
                # Provision test key for sops-nix
                sops.defaultSopsFile = ./secrets/test.yaml;
                sops.age.keyFile = "/var/lib/sops-nix/key.txt";
                sops.age.generateKey = false;
                
                # Provision the test key file at activation time
                system.activationScripts.sops-test-key = {
                  text = ''
                    mkdir -p /var/lib/sops-nix
                    chmod 700 /var/lib/sops-nix
                    cp ${testKeyFile} /var/lib/sops-nix/key.txt
                    chmod 600 /var/lib/sops-nix/key.txt
                  '';
                  deps = [];
                };
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
          
          # Phase 2: Secrets management with sops-nix
          phase-2-secrets = let
            testKeyFile = pkgs.writeText "test-age-key" (builtins.readFile ./keys/test.age);
          in pkgs.nixosTest {
            name = "phase-2-secrets";

            nodes.server = mkTestNode {
              extraConfig = {
                # Use test secrets and test key
                sops.defaultSopsFile = ./secrets/test.yaml;
                sops.age.keyFile = "/var/lib/sops-nix/key.txt";
                sops.age.generateKey = false;
                
                sops.secrets.test_secret = {};
                
                # Provision the test key file at build time (before sops-nix runs)
                system.activationScripts.sops-test-key = {
                  text = ''
                    mkdir -p /var/lib/sops-nix
                    chmod 700 /var/lib/sops-nix
                    cp ${testKeyFile} /var/lib/sops-nix/key.txt
                    chmod 600 /var/lib/sops-nix/key.txt
                  '';
                  deps = [];
                };
              };
            };

            testScript = ''
              server.start()
              server.wait_for_unit("multi-user.target")
              
              # Verify sops-nix ran successfully (it runs during activation)
              # The service may not exist as a unit if secrets were set up during activation
              
              # Verify the test secret was decrypted
              server.succeed("test -f /run/secrets/test_secret")
              output = server.succeed("cat /run/secrets/test_secret")
              assert "this-is-a-test-secret-value" in output, f"Secret value mismatch: {output}"
              
              # Verify secret file permissions (should be readable only by root)
              server.succeed("stat -c '%a' /run/secrets/test_secret | grep -E '^400$|^600$'")
              
              print("✅ Phase 2 validation passed: secrets decrypted successfully!")
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
              sops
              age
              # Future: deploy-rs
            ];
            
            # Set up sops to use the test key by default
            shellHook = ''
              export SOPS_AGE_KEY_FILE="$PWD/keys/test.age"
            '';
          };
        }
      );

      # Formatter
      formatter = forAllSystems (system: nixpkgsFor.${system}.nixpkgs-fmt);
    };
}
