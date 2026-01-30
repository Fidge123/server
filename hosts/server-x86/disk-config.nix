# Declarative disk configuration for x86_64 servers
# Used by nixos-anywhere for initial installation via disko
#
# This configuration is designed for Hetzner Cloud (CX/CPX) servers
# which typically use /dev/sda as the primary disk.
#
# Adjust the device path if using different hardware:
# - Hetzner Cloud: /dev/sda
# - NVMe drives: /dev/nvme0n1
# - VirtIO: /dev/vda
{ lib, ... }:

{
  disko.devices = {
    disk.main = {
      type = "disk";
      # Default to /dev/sda for Hetzner Cloud
      # Override with `disko.devices.disk.main.device` if needed
      device = lib.mkDefault "/dev/sda";
      content = {
        type = "gpt";
        partitions = {
          # BIOS boot partition (for legacy BIOS systems)
          boot = {
            size = "1M";
            type = "EF02";  # BIOS boot partition
          };
          
          # EFI System Partition (for UEFI systems)
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
