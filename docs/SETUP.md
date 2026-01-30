# Setup Guide

This guide covers installing NixOS on a remote server (Hetzner) and on a local VM for testing.

## Supported Architectures

| Architecture | Server Types | Local Testing |
|--------------|--------------|---------------|
| **x86_64-linux** | Hetzner CX/CPX, AWS EC2, DigitalOcean | Linux VM, GitHub Actions |
| **aarch64-linux** | Hetzner CAX (Ampere), AWS Graviton, Oracle ARM | Apple Silicon Mac, ARM Linux |

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

### Building Linux on macOS (Required for VM Tests)

NixOS VM tests require building Linux derivations. On macOS, you need a Linux builder.

#### Option 1: nix-darwin linux-builder (Recommended)

If you use [nix-darwin](https://github.com/LnL7/nix-darwin), add the linux-builder:

```nix
# In your nix-darwin configuration
{
  nix.linux-builder = {
    enable = true;
    ephemeral = true;
    maxJobs = 4;
    config = {
      virtualisation = {
        darwin-builder = {
          diskSize = 40 * 1024;
          memorySize = 8 * 1024;
        };
        cores = 4;
      };
    };
  };
}
```

Then rebuild: `darwin-rebuild switch`

#### Option 2: Manual Linux Builder Setup

Without nix-darwin, set up a Linux builder manually:

```bash
# Start the linux-builder (first time takes a while to build)
nix run nixpkgs#darwin.linux-builder

# In another terminal, the builder is now available
# Nix will automatically use it for Linux builds
```

Add to your Nix configuration (`~/.config/nix/nix.conf`):

```ini
# Enable building for Linux
extra-platforms = aarch64-linux
builders = ssh-ng://linux-builder aarch64-linux /etc/nix/builder_ed25519 4 - - - c3NoLWVkMjU1MTkgQUFBQUMzTnphQzFsWkRJMU5URTVBQUFBSUpCV2N4Yi9CbGFxdDFhdU90RStGOFFVV3JVb3RpQzVxQklRME5mVnhlbGoDnix-daemon
builders-use-substitutes = true
```

#### Option 3: OrbStack / Docker (Alternative)

If you use [OrbStack](https://orbstack.dev/) or Docker Desktop with a Linux VM:

```bash
# Use the Linux VM as a remote builder
# Add to ~/.config/nix/nix.conf:
builders = ssh://orb aarch64-linux
```

#### Verify Linux Builder Works

```bash
# Test that Linux builds work
nix build --system aarch64-linux nixpkgs#hello

# If successful, you can now run VM tests
nix build .#checks.aarch64-linux.phase-3-deploy -L
```

### Testing ARM on Apple Silicon Mac

Apple Silicon Macs can natively run aarch64-linux VMs, making them ideal for testing ARM server configurations.

#### Quick Start (ARM VM on Mac)

```bash
# Build the ARM VM
nix build .#nixosConfigurations.server-arm-vm.config.system.build.vm

# Run the VM
./result/bin/run-server-arm-vm

# SSH into the VM
ssh -p 2222 test@localhost  # password: test
```

#### VM Options for ARM

```bash
# Run with more memory
QEMU_OPTS="-m 4096" ./result/bin/run-server-arm-vm

# Run with port forwarding for web services
QEMU_NET_OPTS="hostfwd=tcp::8080-:80,hostfwd=tcp::2222-:22" ./result/bin/run-server-arm-vm
```

### Testing x86_64 on Linux

#### Option 1: Quick VM with nixos-rebuild (Recommended for Development)

This creates an ephemeral VM from your configuration:

```bash
# Build and run the x86_64 VM
nix build .#nixosConfigurations.server-x86-vm.config.system.build.vm
./result/bin/run-server-x86-vm
```

**VM Access:**
- SSH: `ssh -p 2222 test@localhost` (password: `test`)
- Console: Direct QEMU window (if graphics enabled)

**VM Options:**

```bash
# Run with more memory
QEMU_OPTS="-m 4096" ./result/bin/run-server-x86-vm

# Run with port forwarding for web services
QEMU_NET_OPTS="hostfwd=tcp::8080-:80,hostfwd=tcp::2222-:22" ./result/bin/run-server-x86-vm
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
# Run Phase 1 test for x86_64
nix build .#checks.x86_64-linux.phase-1-flake -L

# Run Phase 1 test for ARM (on Apple Silicon Mac or ARM Linux)
nix build .#checks.aarch64-linux.phase-1-flake -L

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
   - **Type:** Choose based on architecture:
     - **x86_64:** CX22 or larger (4GB RAM minimum)
     - **ARM (aarch64):** CAX11 or larger (Ampere ARM servers)
   - **SSH Key:** Add your public key
   - **Name:** `server-x86` or `server-arm` (or your preferred name)
4. Note the server IP address

> **Note:** Hetzner CAX (ARM Ampere) servers offer excellent price-performance and are fully supported by this configuration.

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

Copy the output and update the appropriate `hosts/server-x86/hardware.nix` or `hosts/server-arm/hardware.nix` with the real hardware configuration.

#### Step 3: Configure Disk Layout

Create a disk configuration file for disko (example for x86_64):

```bash
# Create hosts/server-x86/disk-config.nix (or server-arm for ARM)
cat > hosts/server-x86/disk-config.nix << 'EOF'
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
# For x86_64 server
nix run github:nix-community/nixos-anywhere -- \
  --flake .#server-x86 \
  --generate-hardware-config nixos-generate-config ./hosts/server-x86/hardware.nix \
  root@YOUR_SERVER_IP

# For ARM (aarch64) server
nix run github:nix-community/nixos-anywhere -- \
  --flake .#server-arm \
  --generate-hardware-config nixos-generate-config ./hosts/server-arm/hardware.nix \
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

# Generate hardware config (for x86_64 server)
nixos-generate-config --show-hardware-config > hosts/server-x86/hardware.nix

# Apply configuration
nixos-rebuild switch --flake .#server-x86
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

# Generate hardware configuration (adjust for your architecture)
nixos-generate-config --show-hardware-config > hosts/server-x86/hardware.nix
# Or for ARM: hosts/server-arm/hardware.nix

# Apply configuration (use server-x86 or server-arm)
nixos-rebuild switch --flake .#server-x86
```

## Post-Installation

### Architecture-Specific Configuration

After installation, apply the appropriate configuration:

```bash
# For x86_64 servers
nixos-rebuild switch --flake .#server-x86

# For ARM/aarch64 servers  
nixos-rebuild switch --flake .#server-arm
```

### Add Your SSH Key

Edit `modules/server-common.nix` to add your SSH keys:

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

### Cannot Build Linux Derivations on macOS

If you see errors like:

```
error: Cannot build '...aarch64-linux...'
Required system: 'aarch64-linux' with features {}
Current system: 'aarch64-darwin' with features {...}
```

You need a Linux builder. See [Building Linux on macOS](#building-linux-on-macos-required-for-vm-tests) above.

**Quick fix with nix-darwin:**

```bash
# If you have nix-darwin, enable linux-builder and rebuild
darwin-rebuild switch

# Then retry the build
nix build .#checks.aarch64-linux.phase-3-deploy -L
```

**Quick fix without nix-darwin:**

```bash
# Start the linux-builder in a separate terminal
nix run nixpkgs#darwin.linux-builder

# In your main terminal, retry the build
nix build .#checks.aarch64-linux.phase-3-deploy -L
```

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
  --flake .#server-x86 \
  --debug \
  root@YOUR_SERVER_IP

# Check disk names on target
ssh root@YOUR_SERVER_IP lsblk
```

### Configuration Errors

```bash
# Test build without switching (use server-x86 or server-arm)
nixos-rebuild build --flake .#server-x86

# Show configuration values
nix repl
:lf .
nixosConfigurations.server.config.services.openssh.enable
```

## Secrets Management

This section covers setting up and managing secrets with sops-nix. See [ADR-004](adr/004-secrets-management.md) for the design rationale.

### Overview

We use [sops-nix](https://github.com/Mic92/sops-nix) with [age](https://github.com/FiloSottile/age) encryption:

- **Production secrets:** Encrypted with a dedicated age key, stored in `secrets/secrets.yaml`
- **Test secrets:** Encrypted with a test key (committed to repo), stored in `secrets/test.yaml`
- **Decrypted secrets:** Available at runtime in `/run/secrets/<secret-name>`

### Generate Production Age Key

> ⚠️ **CRITICAL:** Back up your age key immediately after generation. If lost, encrypted secrets cannot be recovered.

```bash
# Enter the development shell (includes age and sops)
nix develop

# Generate a new age key
age-keygen -o server.age

# Output will show:
# Public key: age1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

**Immediately back up the key:**

1. Copy the entire contents of `server.age` to 1Password (or your password manager)
2. Store it as a "Secure Note" named "NixOS Server Age Key"
3. Include the public key in the note for reference
4. Delete the local `server.age` file after backing up

### Configure Production Key

1. **Add the public key to `.sops.yaml`:**

```yaml
keys:
  # Test key for VM testing (committed to repo)
  - &test age1v9649vqesxhtn6yc5tzhrrjvcc8dp77wmzmhthllk4u77959ke9qrp5pam
  
  # Production server - replace with your actual public key
  - &server age1YOUR_ACTUAL_PUBLIC_KEY_HERE

creation_rules:
  - path_regex: secrets/test\.yaml$
    key_groups:
      - age:
          - *test
  
  - path_regex: secrets/secrets\.yaml$
    key_groups:
      - age:
          - *server
```

2. **Create production secrets file:**

```bash
# Create the secrets file (will open in $EDITOR)
sops secrets/secrets.yaml

# Or encrypt an existing file
echo 'my_secret: "actual-secret-value"' > /tmp/secrets.yaml
sops --encrypt --in-place /tmp/secrets.yaml
mv /tmp/secrets.yaml secrets/secrets.yaml
```

3. **Add secrets to the module:**

Edit `modules/sops.nix` to declare your secrets:

```nix
sops.secrets = {
  database_password = { };
  api_key = { 
    owner = "myapp";
    group = "myapp";
  };
};
```

### Provision Key to Server

During server installation, copy the age key to the server:

```bash
# Create the sops directory
ssh root@YOUR_SERVER_IP "mkdir -p /var/lib/sops-nix && chmod 700 /var/lib/sops-nix"

# Copy the key (retrieve from 1Password first)
# Option 1: From a temporary file
scp server.age root@YOUR_SERVER_IP:/var/lib/sops-nix/key.txt
ssh root@YOUR_SERVER_IP "chmod 600 /var/lib/sops-nix/key.txt"

# Option 2: Pipe directly (more secure, no local file)
pbpaste | ssh root@YOUR_SERVER_IP "cat > /var/lib/sops-nix/key.txt && chmod 600 /var/lib/sops-nix/key.txt"
```

### Working with Secrets

```bash
# Enter dev shell (sets SOPS_AGE_KEY_FILE for test secrets)
nix develop

# Decrypt and view test secrets
sops secrets/test.yaml

# Edit secrets (opens in $EDITOR)
sops secrets/test.yaml

# For production secrets, temporarily export your key
export SOPS_AGE_KEY="AGE-SECRET-KEY-1..."
sops secrets/secrets.yaml

# Or use a key file
SOPS_AGE_KEY_FILE=/path/to/server.age sops secrets/secrets.yaml
```

### Accessing Secrets in NixOS

Secrets are decrypted at boot and available as files:

```nix
# In your service configuration
{ config, ... }:
{
  # Reference the secret file
  services.myapp = {
    passwordFile = config.sops.secrets.database_password.path;
    # This evaluates to: /run/secrets/database_password
  };
  
  # Or read it in a script
  systemd.services.myapp = {
    script = ''
      export PASSWORD=$(cat ${config.sops.secrets.database_password.path})
      exec myapp --password-from-env
    '';
  };
}
```

### Validate Secrets Setup

```bash
# Run the Phase 2 VM test
nix build .#checks.x86_64-linux.phase-2-secrets -L

# The test verifies:
# - sops-nix service starts
# - Secrets are decrypted to /run/secrets/
# - File permissions are correct
```

### Key Rotation

To rotate the production age key:

```bash
# 1. Generate new key
age-keygen -o new-server.age

# 2. Add new public key to .sops.yaml (keep old key temporarily)

# 3. Re-encrypt all secrets with both keys
sops updatekeys secrets/secrets.yaml

# 4. Provision new key to server
scp new-server.age root@YOUR_SERVER_IP:/var/lib/sops-nix/key.txt

# 5. Deploy to verify new key works
deploy .#server

# 6. Remove old key from .sops.yaml and re-encrypt
sops updatekeys secrets/secrets.yaml

# 7. Back up new key, delete old key from password manager
```

## Deployment

This section covers deploying NixOS configurations to remote servers.

### Deployment Tools

| Tool | Purpose | When to Use |
|------|---------|-------------|
| **nixos-anywhere** | Initial installation | First-time setup on a fresh server |
| **deploy-rs** | Ongoing deployments | Configuration updates after installation |
| **nixos-rebuild** | Manual deployment | Direct deployment from the server |

### Initial Installation with nixos-anywhere

For first-time installation on a fresh server (see "Remote Server Installation" above for full details):

```bash
# Install on x86_64 server (Hetzner CX/CPX)
nix run github:nix-community/nixos-anywhere -- \
  --flake .#server-x86 \
  root@YOUR_SERVER_IP

# Install on ARM server (Hetzner CAX)
nix run github:nix-community/nixos-anywhere -- \
  --flake .#server-arm \
  root@YOUR_SERVER_IP
```

### Ongoing Deployments with deploy-rs

After initial installation, use deploy-rs for configuration updates:

#### Using the Deploy Helper Script

```bash
# Deploy to x86_64 server
./scripts/deploy.sh server-x86

# Deploy to ARM server
./scripts/deploy.sh server-arm

# Check changes without applying (dry-run)
./scripts/deploy.sh server-x86 --dry-run

# Deploy with verbose output
./scripts/deploy.sh server-x86 --debug

# Show help
./scripts/deploy.sh --help
```

#### Using deploy-rs Directly

```bash
# Enter the development shell (includes deploy-rs)
nix develop

# Deploy to a server
deploy .#server-x86
deploy .#server-arm

# Dry-run (check without applying)
deploy --dry-activate .#server-x86

# Deploy with debug logs
deploy --debug-logs .#server-x86

# Skip confirmation prompt
deploy --auto-rollback=false .#server-x86
```

### Configure Server Hostnames

Before deploying, update the server hostnames in `flake.nix`:

```nix
deploy.nodes = {
  server-x86 = {
    hostname = "server-x86.example.com";  # ← Set your actual hostname or IP
    # ...
  };
  
  server-arm = {
    hostname = "server-arm.example.com";  # ← Set your actual hostname or IP
    # ...
  };
};
```

### Deployment Workflow

**Recommended workflow for configuration changes:**

```bash
# 1. Make changes to your configuration
vim modules/server-common.nix

# 2. Validate the flake
nix flake check

# 3. Dry-run to see what will change
./scripts/deploy.sh server-x86 --dry-run

# 4. Deploy if everything looks good
./scripts/deploy.sh server-x86

# 5. Verify the deployment
ssh root@YOUR_SERVER_IP nixos-version
ssh root@YOUR_SERVER_IP systemctl is-system-running
```

### Rollback

deploy-rs automatically rolls back if the deployment fails. For manual rollback:

```bash
# On the server: list available generations
nix-env --list-generations -p /nix/var/nix/profiles/system

# Roll back to previous generation
nixos-rebuild switch --rollback

# Or switch to a specific generation
nix-env --switch-generation 42 -p /nix/var/nix/profiles/system
/nix/var/nix/profiles/system/bin/switch-to-configuration switch
```

### Disk Configuration (disko)

This project uses [disko](https://github.com/nix-community/disko) for declarative disk partitioning. Disk configurations are located in:

- `hosts/server-x86/disk-config.nix` - x86_64 server disk layout
- `hosts/server-arm/disk-config.nix` - ARM server disk layout

**Default disk layouts:**

| Architecture | Boot Type | Partitions |
|--------------|-----------|------------|
| x86_64 | BIOS + UEFI | 1MB BIOS boot, 512MB ESP, rest ext4 root |
| aarch64 | UEFI only | 512MB ESP, rest ext4 root |

**Customizing disk device:**

The default device is `/dev/sda`. Override if your server uses a different disk:

```nix
# In hosts/server-x86/disk-config.nix (or override in configuration.nix)
disko.devices.disk.main.device = "/dev/nvme0n1";  # For NVMe
disko.devices.disk.main.device = "/dev/vda";      # For VirtIO
```

## Next Steps

After successful installation:

1. **Phase 2:** Set up secrets with sops-nix
2. **Phase 3:** Configure deploy-rs for remote deployments
3. **Phase 4:** Set up PostgreSQL with pgBackRest
4. **Phase 5:** Configure Restic backups

See [PLAN.md](../PLAN.md) for the full implementation plan.
