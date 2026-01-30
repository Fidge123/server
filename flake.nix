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
      # Systems to support for building/testing
      supportedSystems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" "x86_64-darwin" ];
      
      # Helper to generate attributes for each system
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
      
      # Nixpkgs instantiated for each system
      nixpkgsFor = forAllSystems (system: import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      });
      
      # VM module for testing - shared between architectures
      vmModule = { config, pkgs, modulesPath, ... }: {
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
      };
    in
    {
      # NixOS configurations
      nixosConfigurations = {
        # === x86_64-linux configurations ===
        
        # Production x86_64 server
        server-x86 = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = { inherit inputs self; };
          modules = [
            ./hosts/server-x86/configuration.nix
          ];
        };

        # VM configuration for x86_64 testing
        server-x86-vm = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = { inherit inputs self; };
          modules = [
            ./hosts/server-x86/configuration.nix
            vmModule
          ];
        };
        
        # === aarch64-linux (ARM) configurations ===
        
        # Production ARM server
        server-arm = nixpkgs.lib.nixosSystem {
          system = "aarch64-linux";
          specialArgs = { inherit inputs self; };
          modules = [
            ./hosts/server-arm/configuration.nix
          ];
        };

        # VM configuration for ARM testing (can run on Apple Silicon Macs)
        server-arm-vm = nixpkgs.lib.nixosSystem {
          system = "aarch64-linux";
          specialArgs = { inherit inputs self; };
          modules = [
            ./hosts/server-arm/configuration.nix
            vmModule
            # ARM-specific VM overrides
            ({ lib, ... }: {
              # Use systemd-boot for UEFI in VM
              boot.loader.systemd-boot.enable = lib.mkForce true;
              boot.loader.efi.canTouchEfiVariables = lib.mkForce false;
              # Disable grub if it was set
              boot.loader.grub.enable = lib.mkForce false;
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
          
          # Determine if this is a Linux system that can run VM tests
          isLinux = builtins.elem system [ "x86_64-linux" "aarch64-linux" ];
          
          # Common test node configuration that includes sops-nix
          mkTestNode = { extraConfig ? {} }: { config, pkgs, lib, modulesPath, ... }: {
            imports = [ 
              inputs.sops-nix.nixosModules.sops
              ./modules/common.nix
            ];
            
            # Basic server configuration (subset of modules/server-common.nix)
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
          
          # Test definitions that can run on any Linux
          vmTests = let
            testKeyFile = pkgs.writeText "test-age-key" (builtins.readFile ./keys/test.age);
          in {
            # Phase 1: Basic flake test
            phase-1-flake = pkgs.nixosTest {
              name = "phase-1-basic-flake-${system}";

              nodes.server = mkTestNode {
                extraConfig = {
                  # Provision test key for sops-nix  
                  sops.defaultSopsFile = ./secrets/test.yaml;
                  sops.age.keyFile = "/var/lib/sops-nix/key.txt";
                  sops.age.generateKey = false;
                  
                  # Define a dummy secret so setupSecrets script exists
                  sops.secrets.test_secret = {};
                  
                  # Provision the test key file before sops-nix runs
                  system.activationScripts.sops-install-key = {
                    text = ''
                      mkdir -p /var/lib/sops-nix
                      chmod 700 /var/lib/sops-nix
                      cp ${testKeyFile} /var/lib/sops-nix/key.txt
                      chmod 600 /var/lib/sops-nix/key.txt
                    '';
                    deps = [ "specialfs" ];
                  };
                  
                  # Make setupSecrets depend on our key installation
                  system.activationScripts.setupSecrets.deps = [ "sops-install-key" ];
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
                
                print("✅ Phase 1 validation passed on ${system}!")
              '';
            };
            
            # Phase 2: Secrets management with sops-nix
            phase-2-secrets = pkgs.nixosTest {
              name = "phase-2-secrets-${system}";

              nodes.server = mkTestNode {
                extraConfig = {
                  # Use test secrets and test key
                  sops.defaultSopsFile = ./secrets/test.yaml;
                  sops.age.keyFile = "/var/lib/sops-nix/key.txt";
                  sops.age.generateKey = false;
                  
                  sops.secrets.test_secret = {};
                  
                  # Provision the test key file before sops-nix runs
                  system.activationScripts.sops-install-key = {
                    text = ''
                      mkdir -p /var/lib/sops-nix
                      chmod 700 /var/lib/sops-nix
                      cp ${testKeyFile} /var/lib/sops-nix/key.txt
                      chmod 600 /var/lib/sops-nix/key.txt
                    '';
                    deps = [ "specialfs" ];
                  };
                  
                  # Make setupSecrets depend on our key installation
                  system.activationScripts.setupSecrets.deps = [ "sops-install-key" ];
                };
              };

              testScript = ''
                server.start()
                server.wait_for_unit("multi-user.target")
                
                # Verify the test secret was decrypted
                server.succeed("test -f /run/secrets/test_secret")
                output = server.succeed("cat /run/secrets/test_secret")
                assert "this-is-a-test-secret-value" in output, f"Secret value mismatch: {output}"
                
                # Verify secret file permissions (should be readable only by root)
                server.succeed("stat -c '%a' /run/secrets/test_secret | grep -E '^400$|^600$'")
                
                print("✅ Phase 2 validation passed on ${system}: secrets decrypted successfully!")
              '';
            };
          };
        in
        {
          # Basic flake evaluation check (works on all systems including macOS)
          flake-check = pkgs.runCommand "flake-check" {} ''
            echo "Flake evaluation successful on ${system}"
            touch $out
          '';
        } // (if isLinux then vmTests else {})
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
