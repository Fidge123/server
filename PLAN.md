# Implementation Plan: NixOS Self-Hosted Infrastructure

## Overview

This plan implements the NixOS-based self-hosted infrastructure as defined in [ADR-001](docs/adr/001-server-automation-approach.md). Each phase is validated using local VMs before proceeding (see [ADR-002](docs/adr/002-local-vm-testing-strategy.md)).

**Key Principles:**
- Every step is validated in a local VM
- Backup destinations (Storage Box, Raspberry Pi) are optional
- Configuration is fully declarative and reproducible
- All changes are committed to Git before validation

## Progress Summary

| Phase | Description | Status |
|-------|-------------|--------|
| 1 | NixOS Flake Structure | ✅ Complete |
| 2 | Secrets (sops-nix) | ✅ Complete |
| 2.5 | Multi-Architecture Support (x86_64 + aarch64) | ✅ Complete |
| 3 | Deployment (deploy-rs) | ⏳ Not Started |
| 4 | PostgreSQL + pgBackRest | ⏳ Not Started |
| 5 | Restic Backup | ⏳ Not Started |
| 6 | Documentation | 🔄 Partial (SETUP.md updated) |
| 7 | GitHub Actions | 🔄 Partial (validate.yml done) |

## Phase 1: NixOS Flake Structure ✅

**Status:** Complete (January 29, 2026)

### Completed Tasks

- [x] Created `flake.nix` with basic structure
- [x] Created architecture-specific configurations (x86_64 + aarch64)
- [x] Created `modules/common.nix` for shared configuration
- [x] Created `modules/server-common.nix` for shared server settings
- [x] Set up `.gitignore` for Nix artifacts
- [x] Created test framework in `tests/lib.nix`
- [x] Added VM test in flake checks for both architectures

### Files Created

```
├── flake.nix              # Flake entry point
├── flake.lock             # Pinned dependencies
├── .gitignore             # Ignore build artifacts
├── hosts/
│   ├── server-x86/        # x86_64-linux server
│   │   ├── configuration.nix
│   │   └── hardware.nix
│   └── server-arm/        # aarch64-linux server
│       ├── configuration.nix
│       └── hardware.nix
├── modules/
│   └── common.nix
└── tests/
    └── lib.nix            # Test utilities
```

### Validation

```bash
# Validate flake (run on macOS)
nix --extra-experimental-features 'nix-command flakes' flake check

# Evaluate configuration
nix --extra-experimental-features 'nix-command flakes' eval .#nixosConfigurations.server.config.networking.hostName
# Output: "server"

# Run VM test (requires Linux or CI)
nix build .#checks.x86_64-linux.phase-1-flake -L
```

## Phase 2: Secrets Management with sops-nix ✅

**Status:** Complete (January 29, 2026)

### Completed Tasks

- [x] **2.1** Add sops-nix to flake inputs
- [x] **2.2** Create test age key for VM testing (`keys/test.age`)
- [x] **2.3** Create `.sops.yaml` configuration
- [x] **2.4** Create `secrets/test.yaml` with test secret
- [x] **2.5** Create `modules/sops.nix` to configure sops-nix
- [x] **2.6** Integrate secrets into server configuration
- [x] **2.7** Document key generation and backup procedure
- [x] **2.8** Create ADR-004 for secrets management strategy

### Files Created

```
├── .sops.yaml                 # SOPS configuration
├── keys/
│   ├── .gitignore             # Ignore prod keys, keep test key
│   └── test.age               # Test age key (committed)
├── secrets/
│   └── test.yaml              # Encrypted test secrets
├── modules/
│   └── sops.nix               # sops-nix module
└── docs/adr/
    └── 004-secrets-management.md  # ADR for key strategy
```

### Key Management

- **Test key:** Committed to repo (`keys/test.age`) - only encrypts test secrets
- **Production key:** Generated manually, backed up to 1Password
- See [docs/SETUP.md#secrets-management](docs/SETUP.md#secrets-management) for procedures

### Validation

```bash
# Verify test secrets can be decrypted
SOPS_AGE_KEY_FILE=keys/test.age sops -d secrets/test.yaml

# Run VM test
nix build .#checks.x86_64-linux.phase-2-secrets -L
```

## Phase 2.5: Multi-Architecture Support ✅

**Status:** Complete (January 30, 2026)

### Objective

Support both x86_64-linux and aarch64-linux servers, with the ability to test ARM configurations locally on Apple Silicon Macs.

### Completed Tasks

- [x] Separate hardware configurations for x86_64 and aarch64
- [x] Create architecture-specific NixOS configurations in flake.nix
- [x] Add aarch64-linux VM configurations for local testing on ARM Macs
- [x] Enable VM tests for aarch64-linux architecture
- [x] Update documentation (README.md, SETUP.md)

### Architecture

```
hosts/
├── server-x86/           # x86_64-linux server
│   ├── configuration.nix
│   └── hardware.nix
└── server-arm/           # aarch64-linux server
    ├── configuration.nix
    └── hardware.nix
modules/
└── server-common.nix     # Shared server configuration
```

### Local Testing on ARM Mac

```bash
# Build and run ARM VM on Apple Silicon Mac
nix build .#nixosConfigurations.server-arm-vm.config.system.build.vm
./result/bin/run-server-arm-vm

# SSH into the VM
ssh -p 2222 test@localhost  # password: test
```

### Validation

```bash
# Run aarch64-linux checks (on ARM Mac or ARM Linux)
nix build .#checks.aarch64-linux.phase-1-flake -L
nix build .#checks.aarch64-linux.phase-2-secrets -L

# Run x86_64-linux checks (requires x86 Linux or cross-compilation)
nix build .#checks.x86_64-linux.phase-1-flake -L
```

## Phase 3: Remote Deployment with deploy-rs

**Status:** Not Started

### Tasks

- [ ] **3.1** Add deploy-rs to flake inputs
- [ ] **3.2** Configure deploy-rs in flake.nix
- [ ] **3.3** Create deployment profile for server
- [ ] **3.4** Create `scripts/deploy.sh` helper script
- [ ] **3.5** Document deployment process

### Validation

```bash
# Check deployment configuration
nix flake check

# Dry-run deployment
deploy --dry-activate .#server
```

## Phase 4: PostgreSQL with pgBackRest

**Status:** Not Started

### Tasks

- [ ] **4.1** Create `modules/services/postgres.nix`
- [ ] **4.2** Configure PostgreSQL service
- [ ] **4.3** Configure pgBackRest for local backups
- [ ] **4.4** Set up backup schedule
- [ ] **4.5** Configure WAL archiving
- [ ] **4.6** Add database secrets to sops
- [ ] **4.7** Create backup verification tests

### Validation

```bash
# Run VM test
nix build .#checks.x86_64-linux.phase-4-postgres -L

# In VM: verify backup
sudo -u postgres pgbackrest check
sudo -u postgres pgbackrest backup --type=full
```

## Phase 5: Restic Backup with Optional Destinations

**Status:** Not Started

### Design: Optional Backup Destinations

```nix
# modules/backup.nix - Option structure
{
  backup = {
    # Local backup (always enabled)
    localPath = "/var/backup/restic";

    # Hetzner Storage Box (optional)
    storageBox = {
      enable = false;  # Default: disabled
      host = "";
      user = "";
      path = "";
    };

    # Raspberry Pi (optional)
    raspberryPi = {
      enable = false;  # Default: disabled
      host = "";
      port = 8000;
    };
  };
}
```

### Tasks

- [ ] **5.1** Create `modules/backup.nix` with optional destinations
- [ ] **5.2** Configure local Restic backup (always enabled)
- [ ] **5.3** Add Storage Box configuration (optional)
- [ ] **5.4** Add Raspberry Pi configuration (optional)
- [ ] **5.5** Configure backup schedule
- [ ] **5.6** Add Restic secrets to sops
- [ ] **5.7** Create backup monitoring

### Validation

```bash
# Test local-only backup
nix build .#checks.x86_64-linux.phase-5-restic-local -L

# Verify backup in VM
restic -r /var/backup/restic snapshots
```

## Phase 6: Documentation

**Status:** Partial

### Tasks

- [x] **6.1** Write initial server installation guide (`docs/SETUP.md`)
- [ ] **6.2** Document secrets setup and key management
- [ ] **6.3** Document deployment process
- [ ] **6.4** Document backup configuration
- [ ] **6.5** Document optional destination setup
- [x] **6.6** Create troubleshooting guide (in SETUP.md)
- [x] **6.7** Update README.md

## Phase 7: GitHub Actions for GitOps

**Status:** Partial

### Tasks

- [x] **7.1** Create validation workflow (`.github/workflows/validate.yml`)
- [x] **7.2** Create VM test workflow (included in validate.yml)
- [ ] **7.3** Create deployment workflow
- [ ] **7.4** Set up Cachix for build caching
- [ ] **7.5** Configure deployment secrets
- [ ] **7.6** Add deployment protection rules

### Current Workflow

```
Push/PR → Flake Check → Build Config → Run VM Tests
```

### Remaining Work

```
(Future) Merge to main → Deploy to server
```

## Timeline

| Phase | Estimated Effort | Dependencies |
|-------|------------------|--------------|
| ~~1~~ | ~~4-6 hours~~ | ~~None~~ ✅ |
| 2 | 2-3 hours | Phase 1 |
| 3 | 2-3 hours | Phase 1, 2 |
| 4 | 4-6 hours | Phase 1, 2 |
| 5 | 4-6 hours | Phase 1, 2 |
| 6 | 3-4 hours | All above |
| 7 | 3-4 hours | All above |

**Total Remaining: ~18-26 hours**
