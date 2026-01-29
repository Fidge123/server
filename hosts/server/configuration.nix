# Main server configuration
{ config, pkgs, lib, inputs, self, ... }:

{
  imports = [
    ./hardware.nix
    ../../modules/common.nix
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
