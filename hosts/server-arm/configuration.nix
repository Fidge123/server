# Server configuration for aarch64-linux (ARM)
{ config, pkgs, lib, inputs, self, ... }:

{
  imports = [
    ./hardware.nix
    ../../modules/server-common.nix
  ];

  # System identification
  networking.hostName = "server-arm";

  # Boot configuration for UEFI (common on ARM servers)
  boot.loader.systemd-boot.enable = lib.mkDefault true;
  boot.loader.efi.canTouchEfiVariables = lib.mkDefault true;
}
