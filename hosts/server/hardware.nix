# Hardware configuration for server
#
# This file is a placeholder. On a real server, this should be generated using:
#   nixos-generate-config --show-hardware-config > hardware.nix
#
# For Hetzner/cloud providers, this typically includes:
# - Boot loader configuration
# - Disk/filesystem layout
# - Network interface configuration
# - Any hardware-specific kernel modules

{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  # Boot configuration for QEMU/cloud VMs
  boot.initrd.availableKernelModules = [ "ata_piix" "uhci_hcd" "virtio_pci" "virtio_scsi" "sd_mod" "sr_mod" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ ];
  boot.extraModulePackages = [ ];

  # Filesystem (placeholder - will be configured per-server)
  fileSystems."/" = lib.mkDefault {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };

  # Swap (optional, configure as needed)
  swapDevices = [ ];

  # Network configuration
  networking.useDHCP = lib.mkDefault true;

  # Platform
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
