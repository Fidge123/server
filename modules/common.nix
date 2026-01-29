# Common configuration shared across all hosts
{ config, pkgs, lib, ... }:

{
  # Nix configuration
  nix = {
    settings = {
      # Enable flakes and new nix command
      experimental-features = [ "nix-command" "flakes" ];
      
      # Optimize storage
      auto-optimise-store = true;
      
      # Allow building as root
      trusted-users = [ "root" "@wheel" ];
    };
  };

  # Security hardening
  security = {
    # Audit logging
    auditd.enable = true;
    audit = {
      enable = true;
      rules = [
        "-a exit,always -F arch=b64 -S execve"
      ];
    };

    # Sudo configuration
    sudo = {
      enable = true;
      wheelNeedsPassword = lib.mkDefault true;
    };
  };

  # System-wide packages
  environment.systemPackages = with pkgs; [
    # Editors
    vim
    nano

    # System utilities
    htop
    iotop
    ncdu
    tree

    # Network utilities
    curl
    wget
    dnsutils
    inetutils

    # Version control
    git

    # Process management
    tmux
    screen
  ];

  # Enable and configure journald
  services.journald = {
    extraConfig = ''
      SystemMaxUse=500M
      MaxRetentionSec=1month
    '';
  };

  # Automatic security updates
  system.autoUpgrade = {
    enable = true;
    allowReboot = false;  # Require manual reboot
    dates = "04:00";
    flake = "github:your-org/self-hosted";  # Update this after repo is set up
  };

  # Time synchronization
  services.timesyncd.enable = lib.mkDefault true;

  # Documentation
  documentation = {
    enable = true;
    man.enable = true;
  };

  # Default shell configuration
  programs.bash = {
    completion.enable = true;
    # Add useful aliases
    shellAliases = {
      ll = "ls -la";
      update = "sudo nixos-rebuild switch --flake /etc/nixos";
      gc = "sudo nix-collect-garbage -d";
    };
  };
}
