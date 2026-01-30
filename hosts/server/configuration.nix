# Main server configuration
{ config, pkgs, lib, inputs, self, ... }:

{
  imports = [
    ./hardware.nix
    ../../modules/common.nix
    ../../modules/sops.nix
    # Future service imports:
    # ./services/postgres.nix
    # ./services/nginx.nix
    # ./services/authentik.nix
  ];

  # System identification
  networking.hostName = "server";

  # Boot configuration (will be overridden by hardware.nix on real hardware)
  boot.loader.grub.enable = lib.mkDefault true;
  boot.loader.grub.device = lib.mkDefault "/dev/sda";

  # Timezone and locale
  time.timeZone = "Europe/Berlin";
  i18n.defaultLocale = "en_US.UTF-8";

  # System packages
  environment.systemPackages = with pkgs; [
    vim
    git
    htop
    curl
    wget
    tmux
  ];

  # User configuration
  users.users.flori = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDfoXdKei94tFGVToXhJiXGxtZB4m/iok3Xaukl/rtN+JrI4W+oijOGPD3Ol+J/130zO8rXbPizDod3lTg6z11rMnvkty/bjNGHX09gq37ThfGOl6wYLZbrCaOBApbNJR5iVZcYLKIRIHSKgloV7l9sWN9VJDa5pVQbVpBxY5bebk6ST9i8T5UAbg5KePcw49UauYJcpkZK4hqPwfEdD1QRo/LOHM3yb2s42AYmBIbn+Ij2d8ibBFSV/aNmZ4nFaX2Tnj2upvng6lPaeV529u8L44WTbCunKHTEbx/xP/aF3ROCwFHRHokq2x+DiWyM8lTqPfmOxbZV0bO0FDh5XVwt 1Password"
    ];
  };

  # Passwordless sudo for wheel group
  security.sudo.wheelNeedsPassword = false;

  # Enable SSH
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "prohibit-password";
    };
  };

  # Firewall
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 80 443 ];
  };

  # Automatic garbage collection
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  # Enable flakes
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # This value determines the NixOS release
  system.stateVersion = "24.11";
}
