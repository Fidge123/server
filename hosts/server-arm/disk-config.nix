# Declarative disk configuration for aarch64 (ARM) servers
# Used by nixos-anywhere for initial installation via disko
#
# This configuration is designed for ARM servers like:
# - Hetzner CAX (Ampere Altra)
# - AWS Graviton instances
# - Oracle Cloud ARM instances
#
# ARM servers typically boot via UEFI only (no legacy BIOS).
# Common device paths:
# - Hetzner CAX: /dev/sda
# - NVMe drives: /dev/nvme0n1
# - VirtIO: /dev/vda
{ lib, ... }:

{
  disko.devices = {
    disk.main = {
      type = "disk";
      # Default to /dev/sda for Hetzner CAX
      # Override with `disko.devices.disk.main.device` if needed
      device = lib.mkDefault "/dev/sda";
      content = {
        type = "gpt";
        partitions = {
          # EFI System Partition (required for ARM UEFI boot)
          ESP = {
            size = "512M";
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
              mountOptions = [ "umask=0077" ];
            };
          };
          
          # Root partition (rest of the disk)
          root = {
            size = "100%";
            content = {
              type = "filesystem";
              format = "ext4";
              mountpoint = "/";
            };
          };
        };
      };
    };
  };
}
