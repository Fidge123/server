# Implementation Plan: NixOS Self-Hosted Infrastructure

## Overview

This plan implements the NixOS-based self-hosted infrastructure as defined in [ADR-001](docs/adr/001-server-automation-approach.md). Each phase is validated using local VMs before proceeding (see [ADR-002](docs/adr/002-local-vm-testing-strategy.md)).

**Key Principles:**
- Every step is validated in a local VM before deploying to production
- Configuration is fully declarative and reproducible
- All changes are committed to Git before validation
- One shared PostgreSQL instance for all services
- Backup destinations (Storage Box, Raspberry Pi) are optional

## Progress Summary

| Phase | Description | Status |
|-------|-------------|--------|
| 1 | NixOS Flake Structure | ✅ Complete |
| 2 | Secrets (sops-nix) | ✅ Complete |
| 2.5 | Multi-Architecture Support (x86_64 + aarch64) | ✅ Complete |
| 3 | Initial Installation (nixos-anywhere + disko) | ✅ Complete |
| 3.5 | GitOps CI + deploy-rs | 🔄 Partial (validate.yml done) |
| 4 | Reverse Proxy + TLS (nginx + ACME) | ⏳ Not Started |
| 5 | PostgreSQL (shared instance) | ⏳ Not Started |
| 6 | Authentik (SSO) | ⏳ Not Started |
| 7 | Forgejo | ⏳ Not Started |
| 8 | Analytics + Monitoring (Umami, alerting) | ⏳ Not Started |
| 9 | Collaboration Tools (Rallly, karakeep) | ⏳ Not Started |
| 10 | Productivity Tools (Excalidraw, IT Tools, IronCalc, Siyuan, Stirling-PDF) | ⏳ Not Started |
| 11 | Backup (pgBackRest + Restic) | ⏳ Not Started |

---

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

---

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

---

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

### Validation

```bash
# Run aarch64-linux checks (on ARM Mac or ARM Linux)
nix build .#checks.aarch64-linux.phase-1-flake -L
nix build .#checks.aarch64-linux.phase-2-secrets -L

# Run x86_64-linux checks (requires x86 Linux or cross-compilation)
nix build .#checks.x86_64-linux.phase-1-flake -L
```

---

## Phase 3: Initial Server Installation with nixos-anywhere + disko ✅

**Status:** Complete (April 10, 2026)

### Objective

Enable reproducible, automated installation of NixOS on a fresh remote server. A new server can be provisioned with a single command.

### Completed Tasks

- [x] **3.1** Add disko to flake inputs
- [x] **3.2** Create `hosts/server-x86/disk-config.nix` for x86_64 servers
- [x] **3.3** Create `hosts/server-arm/disk-config.nix` for ARM servers
- [x] **3.4** Update host configurations to import disko module and disk config
- [x] **3.5** Document installation process in `docs/SETUP.md`

### Files Created

```
├── hosts/
│   ├── server-x86/
│   │   └── disk-config.nix    # GPT + EFI + ext4 for x86_64
│   └── server-arm/
│       └── disk-config.nix    # GPT + EFI + ext4 for aarch64
```

### Validation

```bash
# Verify flake evaluates correctly with disko
nix flake check

# Initial server installation (requires a fresh server with SSH access)
nix run github:nix-community/nixos-anywhere -- \
  --flake .#server-x86 \
  root@YOUR_SERVER_IP
```

---

## Phase 3.5: GitOps CI + deploy-rs

**Status:** Partial (validate.yml done)

### Objective

Automate deployments via CI: merging to main builds, tests, and pushes a configuration update to the server. deploy-rs provides atomic activation with automatic rollback if the server becomes unreachable after deployment.

Moving CI/CD here (before Phase 4+) means every subsequent service phase benefits from automated deployment and rollback safety from the start.

### Tasks

- [x] **3.5.1** Create validation workflow (`.github/workflows/validate.yml`)
- [x] **3.5.2** VM test workflow (included in validate.yml)
- [ ] **3.5.3** Add deploy-rs to flake inputs
- [ ] **3.5.4** Configure deploy-rs deployment nodes in `flake.nix`
- [ ] **3.5.5** Create deployment workflow (`.github/workflows/deploy.yml`)
- [ ] **3.5.6** Set up Cachix for build caching
- [ ] **3.5.7** Configure deployment secrets (SSH key for deploy-rs in GitHub Actions)
- [ ] **3.5.8** Add deployment protection rules (require passing checks before deploy)

### deploy-rs Configuration

```nix
# In flake.nix inputs:
deploy-rs.url = "github:serokell/deploy-rs";
deploy-rs.inputs.nixpkgs.follows = "nixpkgs";

# Deployment nodes:
deploy.nodes.server-x86 = {
  hostname = "YOUR_SERVER_IP";
  profiles.system = {
    user = "root";
    path = inputs.deploy-rs.lib.x86_64-linux.activate.nixos
      self.nixosConfigurations.server-x86;
  };
};
```

### Target Workflow

```
Merge to main → nix flake check → VM tests → deploy-rs → auto-rollback on failure
```

### Validation

```bash
# Dry-run deployment
nix develop -c deploy --dry-activate .#server-x86
```

---

## Phase 4: Reverse Proxy + TLS

**Status:** Not Started

### Objective

Expose services to the internet with HTTPS. nginx acts as the reverse proxy for all services; ACME (Let's Encrypt) provides certificates automatically. This is a prerequisite for every subsequent service phase.

### Tasks

- [ ] **4.1** Create `modules/nginx.nix` with base nginx configuration
- [ ] **4.2** Configure ACME with Let's Encrypt (email, domain)
- [ ] **4.3** Add wildcard or per-service TLS certificates
- [ ] **4.4** Set up firewall rules for ports 80 and 443
- [ ] **4.5** Add `security.acme` domain to sops secrets (or document manual setup)
- [ ] **4.6** Document how to add a new vhost for future services
- [ ] **4.7** VM test: verify nginx starts and responds on port 80/443

### Design

```nix
# modules/nginx.nix
{
  services.nginx = {
    enable = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;
    recommendedOptimisation = true;
    recommendedGzipSettings = true;
  };

  security.acme = {
    acceptTerms = true;
    defaults.email = "admin@example.com";
  };

  networking.firewall.allowedTCPPorts = [ 80 443 ];
}
```

### Validation

```bash
# Run VM test
nix build .#checks.x86_64-linux.phase-4-nginx -L

# On production: verify certificate renewal
systemctl status acme-YOUR_DOMAIN.service
curl -I https://YOUR_DOMAIN
```

---

## Phase 5: PostgreSQL (Shared Instance)

**Status:** Not Started

### Objective

Deploy a single PostgreSQL instance shared by all services. Per-service databases and users are provisioned declaratively. pgBackRest is configured here so it is ready for each service as it is added; full backup scheduling moves to Phase 11.

Per-service database provisioning follows this pattern to keep database management centralised:

```nix
# modules/postgres.nix
services.postgresql.ensureDatabases = [ "forgejo" "authentik" "umami" "rallly" ];
services.postgresql.ensureUsers = [
  { name = "forgejo";  ensureDBOwnership = true; }
  { name = "authentik"; ensureDBOwnership = true; }
  # ...
];
```

### Tasks

- [ ] **5.1** Create `modules/postgres.nix` (shared instance, per-service provisioning pattern)
- [ ] **5.2** Configure PostgreSQL with sensible defaults (max_connections, shared_buffers)
- [ ] **5.3** Configure pgBackRest repository (local stanza, WAL archiving)
- [ ] **5.4** Add database superuser password to sops secrets
- [ ] **5.5** VM test: verify PostgreSQL starts, databases are created, pgBackRest check passes

### Validation

```bash
# Run VM test
nix build .#checks.x86_64-linux.phase-5-postgres -L

# On production: verify pgBackRest is configured
sudo -u postgres pgbackrest --stanza=main check
```

---

## Phase 6: Authentik (SSO)

**Status:** Not Started

### Objective

Deploy Authentik as the SSO/identity provider. Configured before other services because subsequent services (Forgejo, Umami, etc.) can optionally delegate authentication to Authentik via OAuth2/OIDC. Setting it up first avoids revisiting every service config later.

### Service Deployment Approach

Authentik has no official NixOS module. It will use `virtualisation.oci-containers` (podman or docker). This is the expected approach for most services in this plan — see the note at the top of the service phases.

> **Note on service deployment:** Services without a NixOS module use `virtualisation.oci-containers`. Each service phase follows the same pattern: OCI container config → nginx vhost → sops secrets → database provisioning → VM test.

### Tasks

- [ ] **6.1** Create `modules/services/authentik.nix`
- [ ] **6.2** Configure Authentik server + worker containers
- [ ] **6.3** Provision Authentik's PostgreSQL database and user
- [ ] **6.4** Add Authentik secrets to sops (SECRET_KEY, database password)
- [ ] **6.5** Configure nginx vhost for `auth.YOUR_DOMAIN`
- [ ] **6.6** VM test: verify Authentik starts and health endpoint responds
- [ ] **6.7** Document how to add an OAuth2 provider for a new service

### Validation

```bash
# Run VM test
nix build .#checks.x86_64-linux.phase-6-authentik -L

# On production: verify Authentik is reachable
curl -f https://auth.YOUR_DOMAIN/-/health/live/
```

---

## Phase 7: Forgejo

**Status:** Not Started

### Objective

Deploy Forgejo for Git hosting and project management. Forgejo has a native NixOS module (`services.forgejo`), making this the most declaratively clean service deployment.

### Tasks

- [ ] **7.1** Create `modules/services/forgejo.nix`
- [ ] **7.2** Configure `services.forgejo` (domain, SSH, database)
- [ ] **7.3** Provision Forgejo's PostgreSQL database and user
- [ ] **7.4** Add Forgejo secrets to sops (secret key, database password)
- [ ] **7.5** Configure nginx vhost for `git.YOUR_DOMAIN`
- [ ] **7.6** Configure Forgejo SSH on a non-standard port (e.g. 2222) to avoid conflict with system SSH
- [ ] **7.7** Configure Authentik OAuth2 provider for Forgejo (optional)
- [ ] **7.8** VM test: verify Forgejo starts and API responds

### Validation

```bash
# Run VM test
nix build .#checks.x86_64-linux.phase-7-forgejo -L

# On production: verify Forgejo API
curl -f https://git.YOUR_DOMAIN/api/swagger
```

---

## Phase 8: Analytics + Monitoring

**Status:** Not Started

### Objective

Deploy Umami for privacy-focused web analytics, and set up proactive alerting so the admin is notified when services fail. The README value "if action is necessary, the admin is proactively informed" requires both health monitoring and notification routing.

### Tasks

**Umami:**
- [ ] **8.1** Create `modules/services/umami.nix`
- [ ] **8.2** Configure Umami container
- [ ] **8.3** Provision Umami's PostgreSQL database and user
- [ ] **8.4** Add Umami secrets to sops (APP_SECRET)
- [ ] **8.5** Configure nginx vhost for `analytics.YOUR_DOMAIN`

**Monitoring + Alerting:**
- [ ] **8.6** Configure systemd service failure alerts (email or ntfy notification on unit failure)
- [ ] **8.7** Add disk usage monitoring (alert at 80% full)
- [ ] **8.8** Add certificate expiry monitoring (alert 14 days before expiry)
- [ ] **8.9** VM test: verify Umami starts, verify alert mechanism fires on simulated failure

### Validation

```bash
# Run VM test
nix build .#checks.x86_64-linux.phase-8-umami -L

# On production: verify Umami is reachable
curl -f https://analytics.YOUR_DOMAIN/api/health
```

---

## Phase 9: Collaboration Tools (Rallly, karakeep)

**Status:** Not Started

### Objective

Deploy Rallly (scheduling/polling) and karakeep (bookmarks). Both use PostgreSQL and are deployed as OCI containers.

### Tasks

**Rallly:**
- [ ] **9.1** Create `modules/services/rallly.nix`
- [ ] **9.2** Configure Rallly container
- [ ] **9.3** Provision Rallly's PostgreSQL database and user
- [ ] **9.4** Add Rallly secrets to sops (SECRET_PASSWORD, SMTP credentials)
- [ ] **9.5** Configure nginx vhost for `rallly.YOUR_DOMAIN`

**karakeep:**
- [ ] **9.6** Create `modules/services/karakeep.nix`
- [ ] **9.7** Configure karakeep container
- [ ] **9.8** Provision karakeep's PostgreSQL database and user
- [ ] **9.9** Add karakeep secrets to sops
- [ ] **9.10** Configure nginx vhost for `bookmarks.YOUR_DOMAIN`

**Shared:**
- [ ] **9.11** Configure SMTP relay for outbound email (used by Rallly and future services)
- [ ] **9.12** VM test: verify both services start and respond

### Validation

```bash
nix build .#checks.x86_64-linux.phase-9-collaboration -L
```

---

## Phase 10: Productivity Tools

**Status:** Not Started

### Objective

Deploy the remaining stateless or lightly-stateful tools: Excalidraw (whiteboard), IT Tools (developer utilities), IronCalc (spreadsheets), Siyuan (knowledge management), and Stirling-PDF. Most of these have no database dependency and are thin OCI containers behind nginx.

### Tasks

- [ ] **10.1** Create `modules/services/excalidraw.nix` — nginx vhost `draw.YOUR_DOMAIN`
- [ ] **10.2** Create `modules/services/it-tools.nix` — nginx vhost `tools.YOUR_DOMAIN`
- [ ] **10.3** Create `modules/services/ironcalc.nix` — nginx vhost `calc.YOUR_DOMAIN`
- [ ] **10.4** Create `modules/services/siyuan.nix` — nginx vhost `notes.YOUR_DOMAIN` (needs persistent volume for notebooks)
- [ ] **10.5** Create `modules/services/stirling-pdf.nix` — nginx vhost `pdf.YOUR_DOMAIN`
- [ ] **10.6** Configure Authentik OAuth2 providers for any of the above that support SSO
- [ ] **10.7** VM test: verify all five services start and respond

### Validation

```bash
nix build .#checks.x86_64-linux.phase-10-tools -L
```

---

## Phase 11: Backup

**Status:** Not Started

### Objective

Establish a complete backup strategy once services are deployed and have real data. The 3-2-1 strategy: local backups always enabled, Hetzner Storage Box and Raspberry Pi are optional offsite destinations.

### pgBackRest (Database Backups)

pgBackRest is configured in Phase 5; this phase adds scheduling and offsite replication.

- [ ] **11.1** Configure pgBackRest full backup schedule (weekly)
- [ ] **11.2** Configure pgBackRest incremental backup schedule (daily)
- [ ] **11.3** Configure pgBackRest offsite repository on Hetzner Storage Box (optional)
- [ ] **11.4** Add pgBackRest Storage Box credentials to sops
- [ ] **11.5** VM test: verify full backup and restore cycle

### Restic (File Backups)

```nix
# modules/backup.nix — option structure
{
  backup = {
    localPath = "/var/backup/restic";        # Always enabled

    storageBox = {
      enable = false;                         # Hetzner Storage Box (optional)
      host = "";
      user = "";
      path = "";
    };

    raspberryPi = {
      enable = false;                         # Offsite home backup (optional)
      host = "";
      port = 8000;
    };
  };
}
```

- [ ] **11.6** Create `modules/backup.nix` with optional destination structure
- [ ] **11.7** Configure local Restic repository (always enabled)
- [ ] **11.8** Back up service data volumes (Siyuan notebooks, Forgejo repositories, Authentik media)
- [ ] **11.9** Add Storage Box configuration (optional)
- [ ] **11.10** Add Raspberry Pi configuration (optional)
- [ ] **11.11** Add Restic passwords and remote credentials to sops
- [ ] **11.12** Configure backup monitoring: alert if backup has not run in 25 hours
- [ ] **11.13** VM test: verify local backup and restore

### Validation

```bash
# Run VM test
nix build .#checks.x86_64-linux.phase-11-backup -L

# On production: verify pgBackRest
sudo -u postgres pgbackrest --stanza=main info

# Verify Restic
restic -r /var/backup/restic snapshots
```
