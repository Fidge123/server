# Secrets management with sops-nix
# See ADR-004 for key management strategy
{ config, pkgs, lib, inputs, ... }:

{
  imports = [
    inputs.sops-nix.nixosModules.sops
  ];

  sops = {
    # Default to test secrets; production will override in secrets/secrets.yaml
    # when the production key is configured
    defaultSopsFile = lib.mkDefault ../secrets/test.yaml;
    
    # Age key location on the target system
    # For production: provision this file during installation
    # For testing: this is set up by the test harness
    age.keyFile = lib.mkDefault "/var/lib/sops-nix/key.txt";
    
    # Don't generate a new key if one doesn't exist
    age.generateKey = false;
    
    # Define secrets that will be available at runtime
    # Each secret becomes a file in /run/secrets/<name>
    secrets = {
      test_secret = {
        # Path where the decrypted secret will be available
        # Default: /run/secrets/test_secret
      };
    };
  };

  # Ensure the sops key directory exists
  systemd.tmpfiles.rules = [
    "d /var/lib/sops-nix 0700 root root -"
  ];
}
