# Hardware configuration for x86_64-linux server
#
# This file is a placeholder. On a real server, this should be generated using:
#   nixos-generate-config --show-hardware-config --no-filesystems > hardware.nix
#
# Note: Filesystem configuration is managed by disko (see disk-config.nix)
#
# For Hetzner/cloud providers, this typically includes:
# - Boot loader configuration
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

  # Filesystem configuration is managed by disko (see disk-config.nix)
  # On real hardware, disko will define the proper mount points
  # For VM testing, the VM module overrides fileSystems

  # Swap (optional, configure as needed)
  swapDevices = [ ];

  # Network configuration
  networking.useDHCP = lib.mkDefault true;

  # Platform
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
