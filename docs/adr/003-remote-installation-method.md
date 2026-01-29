# ADR-003: Remote Server Installation Method

## Status
**Accepted** – January 29, 2026

## Context

We need to install NixOS on remote servers (primarily Hetzner Cloud) that typically come with standard Linux distributions like Ubuntu or Debian. The installation method should be:

1. **Reproducible**: Same result every time
2. **Automated**: Minimal manual intervention
3. **Declarative**: Use our existing flake configuration
4. **Reliable**: Well-tested, active community support
5. **Fast**: Minimize deployment time

### Server Environment

- **Provider**: Hetzner Cloud (primary), other VPS providers possible
- **Initial OS**: Ubuntu 24.04 or Debian 12 (provider default)
- **Access**: SSH with root access
- **Network**: Public IPv4/IPv6, no VPN required initially

## Considered Options

### Option 1: nixos-anywhere

**Overview**: [nixos-anywhere](https://github.com/nix-community/nixos-anywhere) is a tool from the nix-community that can install NixOS on any Linux machine via SSH. It boots into a temporary kexec-based NixOS installer, partitions disks using disko, and installs the target configuration.

**How it works**:
1. SSH into target machine running any Linux
2. Downloads and kexec's into a minimal NixOS installer
3. Uses disko to partition disks declaratively
4. Installs NixOS from your flake
5. Reboots into the new system

**Command**:
```bash
nix run github:nix-community/nixos-anywhere -- \
  --flake .#server \
  root@YOUR_SERVER_IP
```

**Pros**:
- ✅ **Fully automated**: Single command installation
- ✅ **Declarative disk partitioning**: Uses disko for reproducible disk layout
- ✅ **Works on any Linux**: No special provider support needed
- ✅ **Flake-native**: Directly uses your flake configuration
- ✅ **Active development**: Regular releases, good documentation
- ✅ **Can generate hardware config**: `--generate-hardware-config` option
- ✅ **Supports secrets**: Can inject sops-nix secrets during install

**Cons**:
- ❌ **Requires disko configuration**: Must define disk layout in Nix
- ❌ **Kexec may fail on some hardware**: Rare, but possible on unusual hardware
- ❌ **Destroys existing data**: Complete disk wipe (expected but worth noting)
- ❌ **Network dependency**: Downloads NixOS during install

**Best for**: Fresh server installations with known disk layout

---

### Option 2: nixos-infect

**Overview**: [nixos-infect](https://github.com/elitak/nixos-infect) is a script that converts an existing Linux installation to NixOS in-place. It replaces the root filesystem contents while preserving the disk layout.

**How it works**:
1. SSH into target machine running Debian/Ubuntu
2. Run nixos-infect script
3. Script installs Nix, generates NixOS config, rebuilds system
4. Reboots into NixOS

**Command**:
```bash
curl https://raw.githubusercontent.com/elitak/nixos-infect/master/nixos-infect | \
  NIX_CHANNEL=nixos-24.11 bash -x
```

**Pros**:
- ✅ **Simple**: Single script, no additional tools
- ✅ **Preserves disk layout**: Reuses existing partitions
- ✅ **Well-established**: Used for years by the community
- ✅ **No disko required**: Works with existing partition scheme
- ✅ **Quick for simple setups**: Fast when defaults are acceptable

**Cons**:
- ❌ **Two-step process**: Infect first, then apply custom config
- ❌ **Non-declarative disk layout**: Inherits whatever the provider set up
- ❌ **Generated config needs cleanup**: Creates default configuration.nix
- ❌ **Less reproducible**: Depends on initial OS state
- ❌ **Limited hardware detection**: May miss some hardware-specific settings
- ❌ **Manual flake integration**: Must clone repo and apply config after

**Best for**: Quick conversions when disk layout doesn't matter

---

### Option 3: Native NixOS Installation

**Overview**: Some providers (including Hetzner) offer NixOS as a directly installable image. This uses the standard NixOS installer, either via ISO mount or provider-specific image.

**How it works**:
1. Select NixOS image in provider console, or
2. Boot from NixOS ISO via provider's rescue/ISO mount feature
3. Follow standard NixOS installation procedure
4. Clone flake repository and apply configuration

**Hetzner options**:
- **Hetzner Cloud**: Apps → NixOS (community image)
- **Hetzner Dedicated**: installimage with NixOS or ISO mount

**Pros**:
- ✅ **Standard installation**: Official NixOS installer
- ✅ **Full control**: Can customize partitioning interactively
- ✅ **Provider-tested**: Image works on provider's hardware
- ✅ **No external tools**: Just NixOS installer

**Cons**:
- ❌ **Manual process**: Interactive installation steps
- ❌ **Provider-dependent**: Not all providers offer NixOS
- ❌ **Non-reproducible partitioning**: Manual disk setup
- ❌ **Two-step process**: Install base, then apply flake
- ❌ **Outdated images**: Provider images may lag behind nixpkgs

**Best for**: When other methods fail, or for learning NixOS installation

---

## Comparison Matrix

| Criteria | nixos-anywhere | nixos-infect | Native Install |
|----------|----------------|--------------|----------------|
| **Automation** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐ |
| **Reproducibility** | ⭐⭐⭐⭐⭐ | ⭐⭐ | ⭐⭐ |
| **Declarative Disks** | ⭐⭐⭐⭐⭐ | ⭐ | ⭐ |
| **Flake Integration** | ⭐⭐⭐⭐⭐ | ⭐⭐ | ⭐⭐ |
| **Simplicity** | ⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐ |
| **Provider Compatibility** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐ |
| **Community Support** | ⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| **Speed** | ⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐ |
| **Learning Curve** | ⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐ |

### Time Comparison

| Method | Estimated Time | Manual Steps |
|--------|----------------|--------------|
| nixos-anywhere | 10-15 minutes | 1 (run command) |
| nixos-infect | 15-20 minutes | 3-4 (infect, clone, configure, rebuild) |
| Native Install | 30-45 minutes | 10+ (interactive installer) |

## Decision

**Primary Method**: nixos-anywhere

**Rationale**:
1. **Single command deployment** aligns with our GitOps goals
2. **Declarative disk partitioning** with disko ensures reproducibility
3. **Direct flake integration** - no intermediate configuration steps
4. **Active maintenance** with good documentation
5. **Supports our secrets workflow** - can inject sops-nix keys during install

## Implementation

### Required Configuration

Add disko to the flake for nixos-anywhere:

```nix
# flake.nix
inputs.disko.url = "github:nix-community/disko";
inputs.disko.inputs.nixpkgs.follows = "nixpkgs";

# hosts/server/configuration.nix
imports = [
  inputs.disko.nixosModules.disko
  ./disk-config.nix
];
```

### Disk Configuration Template

```nix
# hosts/server/disk-config.nix
{ ... }:
{
  disko.devices = {
    disk.main = {
      type = "disk";
      device = "/dev/sda";
      content = {
        type = "gpt";
        partitions = {
          ESP = {
            size = "512M";
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
            };
          };
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
```

### Installation Command

```bash
# From local machine with flake
nix run github:nix-community/nixos-anywhere -- \
  --flake .#server \
  --generate-hardware-config nixos-generate-config ./hosts/server/hardware.nix \
  root@YOUR_SERVER_IP
```

## Consequences

### Positive

- **One-command deployment**: Matches our automation goals
- **Reproducible**: Same disk layout on every install
- **GitOps-friendly**: Configuration from flake, not manual steps
- **Disaster recovery**: Rebuild server identically from repo + backups

### Negative

- **disko learning curve**: Must understand disko configuration
- **Disk wipe required**: Cannot preserve existing data during install
- **Network dependency**: Requires internet during installation

### Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| kexec failure on hardware | Fall back to nixos-infect |
| disko configuration errors | Test disk config in local VM first |
| Network issues during install | Use provider with good connectivity; retry |
| Wrong disk device specified | Verify with `lsblk` before running |

## Follow-up Actions

1. Add disko to flake.nix (Phase 3)
2. Create disk-config.nix for Hetzner servers
3. Test nixos-anywhere in local VM
4. Document fallback procedure with nixos-infect

## References

- [nixos-anywhere Documentation](https://github.com/nix-community/nixos-anywhere)
- [disko Documentation](https://github.com/nix-community/disko)
- [nixos-infect Repository](https://github.com/elitak/nixos-infect)
- [NixOS Installation Guide](https://nixos.org/manual/nixos/stable/#sec-installation)
- [Hetzner NixOS Wiki](https://nixos.wiki/wiki/Hetzner_Cloud)
