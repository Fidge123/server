# Server configuration for x86_64-linux
{ config, pkgs, lib, inputs, self, ... }:

{
  imports = [
    ./hardware.nix
    ./disk-config.nix
    inputs.disko.nixosModules.disko
    ../../modules/server-common.nix
  ];

  # System identification
  networking.hostName = "server-x86";

  # Boot configuration for disko (EFI + BIOS support)
  # GRUB is installed to the EFI partition defined in disk-config.nix
  boot.loader.grub = {
    enable = lib.mkDefault true;
    efiSupport = lib.mkDefault true;
    efiInstallAsRemovable = lib.mkDefault true;  # Works without NVRAM support
    device = lib.mkDefault "nodev";  # Use EFI, not MBR device
  };
}
