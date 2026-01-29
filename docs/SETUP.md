# Setup Guide

This guide covers installing NixOS on a remote server (Hetzner) and on a local VM for testing.

## Prerequisites

### Local Machine Requirements

Install Nix with flakes enabled:

```bash
# Install Nix (Linux/macOS) - Official installer
sh <(curl --proto '=https' --tlsv1.2 -L https://nixos.org/nix/install)

# Enable flakes (add to ~/.config/nix/nix.conf or /etc/nix/nix.conf)
mkdir -p ~/.config/nix
echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf

# Restart nix-daemon (Linux with systemd)
sudo systemctl restart nix-daemon
```

Alternatively, pass the flag with every command:

```bash
nix --extra-experimental-features 'nix-command flakes' flake check
```

### Required Tools

```bash
# These are available in the dev shell
nix develop

# Or install manually:
# - git
# - ssh
# - age (for secrets, Phase 2)
```

## Local VM Installation

Use a local VM for testing configuration changes before deploying to production.

### Option 1: Quick VM with nixos-rebuild (Recommended for Development)

This creates an ephemeral VM from your configuration:

```bash
# Build and run the VM
nix build .#nixosConfigurations.server-vm.config.system.build.vm
./result/bin/run-server-vm

# Or in one command (if nixos-rebuild is available on NixOS)
nixos-rebuild build-vm --flake .#server-vm
./result/bin/run-server-vm
```

**VM Access:**
- SSH: `ssh -p 2222 test@localhost` (password: `test`)
- Console: Direct QEMU window (if graphics enabled)

**VM Options:**

```bash
# Run with more memory
QEMU_OPTS="-m 4096" ./result/bin/run-server-vm

# Run with port forwarding for web services
QEMU_NET_OPTS="hostfwd=tcp::8080-:80,hostfwd=tcp::2222-:22" ./result/bin/run-server-vm
```

### Option 2: Persistent VM with virt-manager

For a persistent VM that survives reboots:

```bash
# 1. Download NixOS ISO
curl -L -o nixos.iso https://channels.nixos.org/nixos-24.11/latest-nixos-minimal-x86_64-linux.iso

# 2. Create VM with virt-manager or qemu
qemu-img create -f qcow2 nixos-test.qcow2 20G

qemu-system-x86_64 \
  -enable-kvm \
  -m 4096 \
  -smp 2 \
  -boot d \
  -cdrom nixos.iso \
  -drive file=nixos-test.qcow2,format=qcow2 \
  -net nic -net user,hostfwd=tcp::2222-:22

# 3. Follow manual NixOS installation (see below)
```

### Option 3: Automated VM Test

Run the automated NixOS VM tests:

```bash
# Run Phase 1 test
nix build .#checks.x86_64-linux.phase-1-flake -L

# The test will:
# - Boot a VM
# - Wait for multi-user.target
# - Verify SSH and firewall are running
# - Report success/failure
```

## Remote Server Installation (Hetzner)

> **Decision**: We use **nixos-anywhere** as the primary installation method.
> See [ADR-003](adr/003-remote-installation-method.md) for a comparison of all methods.

### Method 1: nixos-anywhere (Recommended)

[nixos-anywhere](https://github.com/nix-community/nixos-anywhere) installs NixOS on any Linux server via SSH.

#### Step 1: Create Hetzner Server

1. Log in to [Hetzner Cloud Console](https://console.hetzner.cloud/)
2. Create new project or select existing
3. Add server:
   - **Location:** Choose nearest datacenter
   - **Image:** Ubuntu 24.04 (will be replaced with NixOS)
   - **Type:** CX22 or larger (4GB RAM minimum recommended)
   - **SSH Key:** Add your public key
   - **Name:** `server` (or your preferred name)
4. Note the server IP address

#### Step 2: Generate Hardware Configuration

SSH into the server and generate the hardware config:

```bash
# SSH into the new server
ssh root@YOUR_SERVER_IP

# Install nix temporarily to generate hardware config
sh <(curl -L https://nixos.org/nix/install) --daemon

# Source nix profile
. /etc/profile.d/nix.sh

# Generate hardware configuration
nix-shell -p nixos-install-tools --run "nixos-generate-config --show-hardware-config --no-filesystems"
```

Copy the output and update `hosts/server/hardware.nix` with the real hardware configuration.

#### Step 3: Configure Disk Layout

Create a disk configuration file for disko:

```bash
# Create hosts/server/disk-config.nix
cat > hosts/server/disk-config.nix << 'EOF'
{ ... }:
{
  disko.devices = {
    disk = {
      main = {
        type = "disk";
        device = "/dev/sda";  # Adjust based on your server
        content = {
          type = "gpt";
          partitions = {
            boot = {
              size = "1M";
              type = "EF02";  # BIOS boot partition
            };
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
  };
}
EOF
```

#### Step 4: Install with nixos-anywhere

```bash
# From your local machine
nix run github:nix-community/nixos-anywhere -- \
  --flake .#server \
  --generate-hardware-config nixos-generate-config ./hosts/server/hardware.nix \
  root@YOUR_SERVER_IP
```

This will:
1. Boot into a temporary NixOS installer
2. Partition disks according to disko config
3. Install NixOS with your configuration
4. Reboot into the new system

#### Step 5: Verify Installation

```bash
# SSH into the new NixOS server
ssh root@YOUR_SERVER_IP

# Verify NixOS is running
nixos-version
# Should show: 24.11.xxxxx (...)

# Check system status
systemctl is-system-running
# Should show: running
```

### Method 2: Hetzner installimage + nixos-infect

Alternative method using Hetzner's rescue system:

#### Step 1: Boot into Rescue Mode

1. In Hetzner Cloud Console, select your server
2. Go to **Rescue** tab
3. Enable rescue mode with your SSH key
4. Reboot the server

#### Step 2: Install Base System

```bash
# SSH into rescue system
ssh root@YOUR_SERVER_IP

# Run Hetzner's installimage with Debian
installimage -a -n server -r yes -l 0 -f yes -i images/Debian-bookworm.tar.gz

# Reboot into Debian
reboot
```

#### Step 3: Run nixos-infect

```bash
# SSH into Debian
ssh root@YOUR_SERVER_IP

# Run nixos-infect
curl https://raw.githubusercontent.com/elitak/nixos-infect/master/nixos-infect | NIX_CHANNEL=nixos-24.11 bash -x

# Server will reboot into NixOS
```

#### Step 4: Apply Your Configuration

```bash
# SSH into NixOS
ssh root@YOUR_SERVER_IP

# Clone your repository
git clone https://github.com/YOUR_ORG/self-hosted.git /etc/nixos
cd /etc/nixos

# Generate hardware config
nixos-generate-config --show-hardware-config > hosts/server/hardware.nix

# Apply configuration
nixos-rebuild switch --flake .#server
```

### Method 3: Native NixOS Installation

Hetzner supports native NixOS images:

#### Step 1: Create Server with NixOS Image

1. In Hetzner Cloud Console
2. Create server with **Apps** → **NixOS** image
3. Or use ISO mount with official NixOS ISO

#### Step 2: Initial Setup

```bash
# SSH into the server
ssh root@YOUR_SERVER_IP

# Clone repository
git clone https://github.com/YOUR_ORG/self-hosted.git /etc/nixos
cd /etc/nixos

# Generate hardware configuration
nixos-generate-config --show-hardware-config > hosts/server/hardware.nix

# Apply configuration
nixos-rebuild switch --flake .#server
```

## Post-Installation

### Add Your SSH Key

Edit `hosts/server/configuration.nix` to add your SSH keys:

```nix
users.users.root.openssh.authorizedKeys.keys = [
  "ssh-ed25519 AAAA... your-key-comment"
];

# Or create a regular user
users.users.admin = {
  isNormalUser = true;
  extraGroups = [ "wheel" ];
  openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAA... your-key-comment"
  ];
};
```

### Apply Configuration Changes

```bash
# From the server
cd /etc/nixos
git pull
nixos-rebuild switch --flake .#server

# Or remotely (after deploy-rs is set up in Phase 3)
deploy .#server
```

### Verify Services

```bash
# Check all services are running
systemctl status

# Check listening ports
ss -tlnp

# Check firewall rules
iptables -L -n
```

## Troubleshooting

### Flake Check Fails

```bash
# Show detailed error trace
nix flake check --show-trace

# Check specific configuration
nix eval .#nixosConfigurations.server.config.services --json | jq
```

### VM Won't Start

```bash
# Check KVM is available (Linux)
ls -la /dev/kvm

# If permission denied
sudo usermod -aG kvm $USER
# Then log out and back in

# On macOS, use HVF instead of KVM
QEMU_OPTS="-accel hvf" ./result/bin/run-server-vm
```

### SSH Connection Refused

```bash
# Check SSH is running on server
systemctl status sshd

# Check firewall
iptables -L -n | grep 22

# Verify SSH key is correct
ssh -v root@YOUR_SERVER_IP
```

### nixos-anywhere Fails

```bash
# Check network connectivity
ping YOUR_SERVER_IP

# Try with verbose output
nix run github:nix-community/nixos-anywhere -- \
  --flake .#server \
  --debug \
  root@YOUR_SERVER_IP

# Check disk names on target
ssh root@YOUR_SERVER_IP lsblk
```

### Configuration Errors

```bash
# Test build without switching
nixos-rebuild build --flake .#server

# Show configuration values
nix repl
:lf .
nixosConfigurations.server.config.services.openssh.enable
```

## Next Steps

After successful installation:

1. **Phase 2:** Set up secrets with sops-nix
2. **Phase 3:** Configure deploy-rs for remote deployments
3. **Phase 4:** Set up PostgreSQL with pgBackRest
4. **Phase 5:** Configure Restic backups

See [PLAN.md](../PLAN.md) for the full implementation plan.
