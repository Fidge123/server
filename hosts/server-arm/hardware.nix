# Hardware configuration for aarch64-linux (ARM) server
#
# This file is a placeholder. On a real server, this should be generated using:
#   nixos-generate-config --show-hardware-config > hardware.nix
#
# For ARM cloud providers (Hetzner Ampere, AWS Graviton, Oracle ARM), this typically includes:
# - UEFI boot loader configuration
# - Disk/filesystem layout
# - Network interface configuration
# - Any hardware-specific kernel modules

{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  # Boot configuration for QEMU/cloud VMs on ARM
  boot.initrd.availableKernelModules = [ "virtio_pci" "virtio_scsi" "virtio_blk" "virtio_net" "sd_mod" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ ];
  boot.extraModulePackages = [ ];

  # Filesystem (placeholder - will be configured per-server)
  fileSystems."/" = lib.mkDefault {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };

  # EFI System Partition (required for UEFI boot on ARM)
  fileSystems."/boot" = lib.mkDefault {
    device = "/dev/disk/by-label/boot";
    fsType = "vfat";
  };

  # Swap (optional, configure as needed)
  swapDevices = [ ];

  # Network configuration
  networking.useDHCP = lib.mkDefault true;

  # Platform
  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";
}
