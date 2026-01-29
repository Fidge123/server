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
| 2 | Secrets (sops-nix) | ⏳ Not Started |
| 3 | Deployment (deploy-rs) | ⏳ Not Started |
| 4 | PostgreSQL + pgBackRest | ⏳ Not Started |
| 5 | Restic Backup | ⏳ Not Started |
| 6 | Documentation | 🔄 Partial (SETUP.md done) |
| 7 | GitHub Actions | 🔄 Partial (validate.yml done) |

## Phase 1: NixOS Flake Structure ✅

**Status:** Complete (January 29, 2026)

### Completed Tasks

- [x] Created `flake.nix` with basic structure
- [x] Created `hosts/server/configuration.nix` with minimal config
- [x] Created `hosts/server/hardware.nix` placeholder
- [x] Created `modules/common.nix` for shared configuration
- [x] Set up `.gitignore` for Nix artifacts
- [x] Created test framework in `tests/lib.nix`
- [x] Added VM test in flake checks

### Files Created

```
├── flake.nix              # Flake entry point
├── flake.lock             # Pinned dependencies
├── .gitignore             # Ignore build artifacts
├── hosts/
│   └── server/
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

## Phase 2: Secrets Management with sops-nix

**Status:** Not Started

### Tasks

- [ ] **2.1** Add sops-nix to flake inputs
- [ ] **2.2** Generate age key for secrets encryption
- [ ] **2.3** Create `.sops.yaml` configuration
- [ ] **2.4** Create `secrets/secrets.yaml` with test secret
- [ ] **2.5** Create `modules/secrets.nix` to configure sops-nix
- [ ] **2.6** Integrate secrets into server configuration
- [ ] **2.7** Document key backup procedure (1Password)

### Validation

```bash
# Verify secrets can be decrypted
sops -d secrets/secrets.yaml

# Run VM test
nix build .#checks.x86_64-linux.phase-2-secrets -L
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

- [ ] **4.1** Create `hosts/server/services/postgres.nix`
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
