# Server configuration for aarch64-linux (ARM)
{ config, pkgs, lib, inputs, self, ... }:

{
  imports = [
    ./hardware.nix
    ./disk-config.nix
    inputs.disko.nixosModules.disko
    ../../modules/server-common.nix
  ];

  # System identification
  networking.hostName = "server-arm";

  # Boot configuration for UEFI (ARM servers use UEFI exclusively)
  # systemd-boot is installed to the EFI partition defined in disk-config.nix
  boot.loader.systemd-boot.enable = lib.mkDefault true;
  boot.loader.efi.canTouchEfiVariables = lib.mkDefault false;  # Works in VMs and restricted environments
}
