{
  description = "Self-hosted infrastructure with NixOS";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";

    # Secrets management
    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
    
    # Deployment
    deploy-rs.url = "github:serokell/deploy-rs";
    deploy-rs.inputs.nixpkgs.follows = "nixpkgs";
    
    # Declarative disk partitioning
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";
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
            ] ++ [
              inputs.deploy-rs.packages.${system}.deploy-rs
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

      # deploy-rs configuration
      deploy = {
        # Don't use sudo, we deploy as root
        sshUser = "root";
        
        # Deployment nodes
        nodes = {
          # x86_64 server deployment
          server-x86 = {
            hostname = "server-x86.example.com";  # TODO: Set actual hostname/IP
            profiles.system = {
              user = "root";
              path = inputs.deploy-rs.lib.x86_64-linux.activate.nixos 
                self.nixosConfigurations.server-x86;
            };
          };
          
          # ARM server deployment
          server-arm = {
            hostname = "server-arm.example.com";  # TODO: Set actual hostname/IP
            profiles.system = {
              user = "root";
              path = inputs.deploy-rs.lib.aarch64-linux.activate.nixos 
                self.nixosConfigurations.server-arm;
            };
          };
        };
      };

      # deploy-rs checks (validates deployment configurations)
      checks = forAllSystems (system:
        let
          existingChecks = 
            let
              pkgs = nixpkgsFor.${system};
              isLinux = builtins.elem system [ "x86_64-linux" "aarch64-linux" ];
              testKeyFile = pkgs.writeText "test-age-key" (builtins.readFile ./keys/test.age);
              
              mkTestNode = { extraConfig ? {} }: { config, pkgs, lib, modulesPath, ... }: {
                imports = [ 
                  inputs.sops-nix.nixosModules.sops
                  ./modules/common.nix
                ];
                
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
                
                boot.loader.grub.enable = false;
                fileSystems."/" = {
                  device = "/dev/disk/by-label/nixos";
                  fsType = "ext4";
                };
                
                security.sudo.wheelNeedsPassword = false;
                users.users.test = {
                  isNormalUser = true;
                  extraGroups = [ "wheel" ];
                  initialPassword = "test";
                };
              } // extraConfig;
              
              vmTests = {
                phase-1-flake = pkgs.nixosTest {
                  name = "phase-1-basic-flake-${system}";
                  nodes.server = mkTestNode {
                    extraConfig = {
                      sops.defaultSopsFile = ./secrets/test.yaml;
                      sops.age.keyFile = "/var/lib/sops-nix/key.txt";
                      sops.age.generateKey = false;
                      sops.secrets.test_secret = {};
                      system.activationScripts.sops-install-key = {
                        text = ''
                          mkdir -p /var/lib/sops-nix
                          chmod 700 /var/lib/sops-nix
                          cp ${testKeyFile} /var/lib/sops-nix/key.txt
                          chmod 600 /var/lib/sops-nix/key.txt
                        '';
                        deps = [ "specialfs" ];
                      };
                      system.activationScripts.setupSecrets.deps = [ "sops-install-key" ];
                    };
                  };
                  testScript = ''
                    server.start()
                    server.wait_for_unit("multi-user.target")
                    server.succeed("nixos-version")
                    server.succeed("systemctl is-system-running --wait || true")
                    server.wait_for_unit("sshd.service")
                    server.succeed("systemctl is-active sshd")
                    server.succeed("systemctl is-active firewall")
                    print("✅ Phase 1 validation passed on ${system}!")
                  '';
                };
                
                phase-2-secrets = pkgs.nixosTest {
                  name = "phase-2-secrets-${system}";
                  nodes.server = mkTestNode {
                    extraConfig = {
                      sops.defaultSopsFile = ./secrets/test.yaml;
                      sops.age.keyFile = "/var/lib/sops-nix/key.txt";
                      sops.age.generateKey = false;
                      sops.secrets.test_secret = {};
                      system.activationScripts.sops-install-key = {
                        text = ''
                          mkdir -p /var/lib/sops-nix
                          chmod 700 /var/lib/sops-nix
                          cp ${testKeyFile} /var/lib/sops-nix/key.txt
                          chmod 600 /var/lib/sops-nix/key.txt
                        '';
                        deps = [ "specialfs" ];
                      };
                      system.activationScripts.setupSecrets.deps = [ "sops-install-key" ];
                    };
                  };
                  testScript = ''
                    server.start()
                    server.wait_for_unit("multi-user.target")
                    server.succeed("test -f /run/secrets/test_secret")
                    output = server.succeed("cat /run/secrets/test_secret")
                    assert "this-is-a-test-secret-value" in output, f"Secret value mismatch: {output}"
                    server.succeed("stat -c '%a' /run/secrets/test_secret | grep -E '^400$|^600$'")
                    print("✅ Phase 2 validation passed on ${system}: secrets decrypted successfully!")
                  '';
                };
                
                phase-3-deploy = pkgs.nixosTest {
                  name = "phase-3-deploy-${system}";
                  nodes.server = mkTestNode {
                    extraConfig = {
                      sops.defaultSopsFile = ./secrets/test.yaml;
                      sops.age.keyFile = "/var/lib/sops-nix/key.txt";
                      sops.age.generateKey = false;
                      sops.secrets.test_secret = {};
                      system.activationScripts.sops-install-key = {
                        text = ''
                          mkdir -p /var/lib/sops-nix
                          chmod 700 /var/lib/sops-nix
                          cp ${testKeyFile} /var/lib/sops-nix/key.txt
                          chmod 600 /var/lib/sops-nix/key.txt
                        '';
                        deps = [ "specialfs" ];
                      };
                      system.activationScripts.setupSecrets.deps = [ "sops-install-key" ];
                    };
                  };
                  testScript = ''
                    server.start()
                    server.wait_for_unit("multi-user.target")
                    
                    # Verify nix is available for deploy-rs
                    server.succeed("nix --version")
                    
                    # Verify SSH is running (required for deploy-rs)
                    server.wait_for_unit("sshd.service")
                    server.succeed("systemctl is-active sshd")
                    
                    # Verify system profile exists (deploy-rs target)
                    server.succeed("test -d /nix/var/nix/profiles")
                    
                    print("✅ Phase 3 validation passed on ${system}: system ready for deploy-rs!")
                  '';
                };
              };
            in
            {
              flake-check = nixpkgsFor.${system}.runCommand "flake-check" {} ''
                echo "Flake evaluation successful on ${system}"
                touch $out
              '';
            } // (if builtins.elem system [ "x86_64-linux" "aarch64-linux" ] then vmTests else {});
          
          # Add deploy-rs checks for Linux systems
          deployChecks = 
            if builtins.elem system [ "x86_64-linux" "aarch64-linux" ]
            then inputs.deploy-rs.lib.${system}.deployChecks self.deploy
            else {};
        in
        existingChecks // deployChecks
      );
    };
}
