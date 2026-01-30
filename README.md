# Self-Hosted

This repository contains code and instructions to set up a number of self-hosted components on one or many virtual private servers using NixOS.

Most services will be used by one user or at most 10 users.

## Supported Architectures

| Architecture | Description | Test Environment |
|--------------|-------------|------------------|
| **x86_64-linux** | Intel/AMD servers (Hetzner, most VPS) | Linux VM or CI |
| **aarch64-linux** | ARM servers (Hetzner Ampere, AWS Graviton, Oracle ARM) | Apple Silicon Mac or ARM Linux |

## Project Status

**Current Phase:** Planning Complete - Awaiting Implementation

See [PLAN.md](PLAN.md) for the detailed implementation plan and [ADR-001](docs/adr/001-server-automation-approach.md) for the architectural decision.

### Technology Stack

| Component | Technology |
|-----------|------------|
| **Operating System** | NixOS with Flakes |
| **Secrets Management** | sops-nix with age encryption |
| **Deployment** | deploy-rs |
| **Database Backup** | pgBackRest |
| **Data Backup** | Restic (optional multi-destination) |
| **CI/CD** | GitHub Actions |

## Values

- Setting up a new server should be possible within a few minutes
  - Every configuration should be done in code or documented
  - Data needs to be backed-up
- Running costs should be minimized
  - Keep resource usage low by using one database if possible
- Regular maintenance should be minimal
  - Updates happen automatically
  - If action is necessary, the admin is proactively informed
  - Keep things simple
- No compromises when it comes to security 
  - Follow best practices
  - Secrets and keys are stored securely

## Services

Open-Source services:
- [Rallly](https://github.com/lukevella/rallly): Scheduling and collaboration tool
- [Excalidraw](https://github.com/excalidraw/excalidraw): Virtual whiteboard
- [Stirling-PDF](https://github.com/Stirling-Tools/Stirling-PDF): Edit PDF online
- [IT Tools](https://github.com/CorentinTh/it-tools): Handy online tools for developers
- [Iron Calc](https://github.com/ironcalc/IronCalc): Online spreadsheets
- [Siyuan](https://github.com/siyuan-note/siyuan): Personal knowledge management
- [Forgejo](https://forgejo.org): Git repository hosting and project management 
- [karakeep](https://github.com/karakeep-app/karakeep): Bookmark everything app
- [Umami](https://github.com/umami-software/umami): Privacy-focused analytics
- [Authentik](https://github.com/goauthentik/authentik): Authentication management
- [PostgreSQL](https://www.postgresql.org): Database

## Documentation

- [PLAN.md](PLAN.md) - Implementation plan with phases and validation steps
- [docs/SETUP.md](docs/SETUP.md) - Installation and setup guide
- [docs/adr/](docs/adr/) - Architecture Decision Records

## Quick Start

### Prerequisites

Install Nix with flakes support:

```bash
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
```

### Validate Configuration

```bash
# Clone this repository
git clone https://github.com/your-org/self-hosted.git
cd self-hosted

# Validate the NixOS configuration
nix flake check

# Run VM tests for x86_64 (requires x86_64 Linux or CI)
nix build .#checks.x86_64-linux.phase-1-flake -L

# Run VM tests for ARM (on Apple Silicon Mac or ARM Linux)
nix build .#checks.aarch64-linux.phase-1-flake -L
```

### Test in Local VM

#### x86_64 (Intel/AMD)

```bash
# Build and run x86_64 test VM
nix build .#nixosConfigurations.server-x86-vm.config.system.build.vm
./result/bin/run-server-x86-vm

# SSH into the VM
ssh -p 2222 test@localhost  # password: test
```

#### aarch64 (ARM - Apple Silicon Mac)

```bash
# Build and run ARM test VM (on Apple Silicon Mac)
nix build .#nixosConfigurations.server-arm-vm.config.system.build.vm
./result/bin/run-server-arm-vm

# SSH into the VM
ssh -p 2222 test@localhost  # password: test
```

### Deploy to Production

See [docs/SETUP.md](docs/SETUP.md) for full installation instructions on:
- Local VM testing (x86_64 and ARM)
- Hetzner Cloud servers (x86_64 and ARM Ampere)
- Other VPS providers

```bash
# After initial server setup (Phase 3)
deploy .#server
```

## Backup Strategy

Backups follow the 3-2-1 strategy with **optional remote destinations**:

| Destination | Type | Status |
|-------------|------|--------|
| Local server | On-site | Always enabled |
| Hetzner Storage Box | Offsite (cloud) | Optional |
| Raspberry Pi | Offsite (home) | Optional |

See [PLAN.md](PLAN.md#phase-5-restic-backup-with-optional-destinations) for configuration details.
