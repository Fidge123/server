# Server configuration for x86_64-linux
{ config, pkgs, lib, inputs, self, ... }:

{
  imports = [
    ./hardware.nix
    ../../modules/server-common.nix
  ];

  # System identification
  networking.hostName = "server-x86";

  # Boot configuration (will be overridden by hardware.nix on real hardware)
  boot.loader.grub.enable = lib.mkDefault true;
  boot.loader.grub.device = lib.mkDefault "/dev/sda";
}
