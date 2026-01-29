# ADR-001: Server Automation Approach

## Status
**Accepted** – January 29, 2026

## Context

We need to establish an automated, documented approach for deploying and managing a self-hosted server infrastructure. The setup must support the following services:

**Core Infrastructure:**
- PostgreSQL (shared database for multiple services)
- Authentik (SSO/authentication)

**Applications:**
- Rallly (scheduling)
- Excalidraw (whiteboard)
- Stirling-PDF (PDF tools)
- IT Tools (developer utilities)
- Iron Calc (spreadsheets)
- Siyuan (knowledge management)
- Forgejo (Git hosting)
- Karakeep (bookmarks)
- Umami (analytics)

### Requirements Summary

| Requirement | Details |
|-------------|---------|
| **Infrastructure** | Single server, 4 cores, 8GB RAM, 512GB storage |
| **Provider** | Agnostic (currently Hetzner/Netcup) |
| **Database** | Shared PostgreSQL, separate DB per service |
| **Authentication** | Authentik as central SSO |
| **Deployment** | GitOps preferred (soft requirement) |
| **Backups** | Offsite, 24h RPO acceptable |
| **Secrets** | TBD (1Password available) |
| **Maintenance** | <15 min/month, months of unattended operation |
| **Experience** | Basic Docker/Linux, no NixOS experience |

### Decision Drivers

1. **Setup Speed**: New server operational within minutes
2. **Reproducibility**: Configuration as code, easy disaster recovery
3. **Low Maintenance**: Automatic updates, minimal intervention
4. **Security**: Best practices, secure secrets management
5. **Simplicity**: Manageable complexity for single-person operation
6. **Learning Curve**: Reasonable for someone with basic Docker/Linux knowledge

## Considered Options

### Option 1: NixOS with Declarative Configuration

**Overview**: NixOS is a Linux distribution built on the Nix package manager, using a purely functional approach to system configuration. The entire system (OS, packages, services) is defined in `.nix` files.

**How it works**:
- Server runs NixOS instead of Ubuntu/Debian
- All configuration in `configuration.nix` and related files
- Use Flakes for reproducibility and version pinning
- Native NixOS modules available for PostgreSQL, nginx, etc.
- Containers run via `virtualisation.oci-containers`

**GitOps Compatibility**: ⭐⭐⭐⭐⭐
- Excellent. Push to Git → rebuild system via `nixos-rebuild switch --flake`
- Tools like [deploy-rs](https://github.com/serokell/deploy-rs) or [colmena](https://github.com/zhaofengli/colmena) enable remote deployment

**Secrets Management**:
- [sops-nix](https://github.com/Mic92/sops-nix): Encrypts secrets with age/GPG, decrypts at build time
- [agenix](https://github.com/ryantm/agenix): Similar, lighter weight
- 1Password integration possible via 1Password CLI in activation scripts

**Pros**:
- ✅ **Complete reproducibility**: Entire OS state is declarative
- ✅ **Atomic upgrades and rollbacks**: System-wide, instant rollback on failure
- ✅ **No configuration drift**: System always matches declared state
- ✅ **Extensive package repository**: 120,000+ packages in nixpkgs
- ✅ **Native service modules**: PostgreSQL, nginx, Authentik have NixOS modules
- ✅ **Single tool for everything**: OS, packages, services, containers
- ✅ **Excellent for disaster recovery**: Rebuild identical server from config

**Cons**:
- ❌ **Steep learning curve**: Nix language is unique and requires investment
- ❌ **Different mental model**: Functional approach differs from traditional Linux
- ❌ **Debugging can be harder**: Errors in Nix expressions can be cryptic
- ❌ **Not all services have modules**: May need to use containers for some apps
- ❌ **Community smaller than Docker**: Fewer tutorials, Stack Overflow answers
- ❌ **Provider support**: Must use NixOS image or install manually (Hetzner supports it)

**Resource Overhead**: Minimal (native services)

**Additional Costs**: None

### Option 2: Uncloud

**Overview**: Uncloud is a lightweight container orchestration tool that creates a WireGuard mesh network between Docker hosts. It uses familiar Docker Compose syntax and provides automatic HTTPS, service discovery, and load balancing without a central control plane.

**How it works**:
- Install Uncloud CLI locally, initialize remote machine(s)
- Deploy services using `docker-compose.yaml` files
- Built-in Caddy reverse proxy handles HTTPS/TLS
- Peer-to-peer state synchronization (no central database)

**GitOps Compatibility**: ⭐⭐⭐
- Manual: Push to Git → SSH and run `uc compose up`
- Could script with CI/CD pipelines (GitHub Actions)
- No built-in GitOps support yet

**Secrets Management**:
- Environment variables in compose files
- Could use SOPS to encrypt compose files in Git
- Docker secrets supported
- 1Password CLI integration possible

**Pros**:
- ✅ **Familiar Docker Compose syntax**: Minimal learning curve
- ✅ **Zero-downtime deployments**: Rolling updates built-in
- ✅ **Automatic HTTPS**: Caddy + Let's Encrypt out of the box
- ✅ **No control plane overhead**: Decentralized, resilient
- ✅ **Built-in image registry**: Push images directly to machines
- ✅ **Easy multi-server scaling**: Add machines with one command
- ✅ **Active development**: Regular releases, responsive maintainer

**Cons**:
- ⚠️ **Not production-ready**: Project explicitly states this
- ❌ **Young project**: Less battle-tested, potential breaking changes
- ❌ **No built-in backup solution**: Must implement separately
- ❌ **Limited ecosystem**: Fewer integrations, tutorials
- ❌ **No web UI**: CLI-only operation
- ❌ **Single-server less compelling**: Main benefits are multi-server

**Resource Overhead**: Low (~100MB for Uncloud daemon + Caddy)

**Additional Costs**: None (managed DNS `*.uncld.dev` is free)

### Option 3: Docker Compose with Ansible

**Overview**: Traditional infrastructure-as-code approach using Ansible for server provisioning and Docker Compose for service definitions. Widely adopted, well-documented pattern.

**How it works**:
- Ansible playbooks configure server (packages, users, firewall, Docker)
- Docker Compose files define services
- Traefik or nginx-proxy for reverse proxy and HTTPS
- Run `ansible-playbook` to apply changes

**GitOps Compatibility**: ⭐⭐⭐⭐
- Push to Git → CI/CD runs `ansible-playbook`
- Tools like Ansible AWX/Semaphore for GitOps workflows
- Watchtower for automatic container updates

**Secrets Management**:
- [Ansible Vault](https://docs.ansible.com/ansible/latest/vault_guide/index.html): Encrypt variables/files in Git
- [1Password Ansible lookup](https://developer.1password.com/docs/ansible/): Native 1Password integration ✨
- SOPS with ansible-sops plugin
- Environment files with restricted permissions

**Pros**:
- ✅ **Mature ecosystem**: Thousands of roles on Ansible Galaxy
- ✅ **Familiar Docker Compose**: Easy to understand service definitions
- ✅ **Excellent documentation**: Many tutorials, examples, courses
- ✅ **1Password native integration**: Official Ansible collection
- ✅ **Idempotent**: Safe to run multiple times
- ✅ **Gradual adoption**: Can automate incrementally
- ✅ **Works with any Linux distro**: Ubuntu, Debian, etc.

**Cons**:
- ❌ **Two tools to learn**: Ansible + Docker Compose
- ❌ **YAML verbosity**: Playbooks can become lengthy
- ❌ **No atomic rollbacks**: Rollback requires running previous playbook
- ❌ **State drift possible**: Server can diverge from playbook
- ❌ **Python dependency**: Ansible requires Python on control machine
- ❌ **Container-only services**: OS-level changes less elegant

**Resource Overhead**: Low (just Docker + containers)

**Additional Costs**: None (unless using Ansible AWX/Tower)

### Option 4: Docker Compose with cloud-init

**Overview**: Minimal approach using cloud-init for initial server provisioning and Docker Compose for services. Cloud-init is supported by most VPS providers for first-boot configuration.

**How it works**:
- cloud-init YAML configures server on first boot
- Docker and Docker Compose installed via cloud-init
- Services defined in docker-compose.yaml
- Updates via SSH or simple bash scripts

**GitOps Compatibility**: ⭐⭐
- Cloud-init only runs on first boot
- Subsequent changes require SSH + manual intervention
- Could use Watchtower for container updates
- Less suitable for true GitOps

**Secrets Management**:
- Environment files on server
- Could encrypt with SOPS before transfer
- 1Password CLI for fetching secrets in scripts
- Less elegant than other options

**Pros**:
- ✅ **Simplest approach**: Minimal tooling to learn
- ✅ **Provider native**: Hetzner, Netcup, all major providers support cloud-init
- ✅ **Fast initial setup**: Server ready on first boot
- ✅ **No local dependencies**: Just need SSH access
- ✅ **Easy to understand**: Standard Docker Compose workflow

**Cons**:
- ❌ **One-time provisioning**: cloud-init doesn't handle updates
- ❌ **Manual updates**: Changes require SSH and manual work
- ❌ **No idempotency**: Re-running is not safe/meaningful
- ❌ **State drift likely**: Server configuration diverges over time
- ❌ **Poor disaster recovery**: Hard to recreate exact state
- ❌ **Limited GitOps**: Not designed for continuous deployment

**Resource Overhead**: Minimal (just Docker)

**Additional Costs**: None

### Option 5: Kamal

**Overview**: Kamal is a deployment tool from 37signals (creators of Basecamp, HEY) that deploys containerized applications to any server via SSH. Uses an imperative approach with kamal-proxy for zero-downtime deployments.

**How it works**:
- Define deployment in `config/deploy.yml`
- Run `kamal setup` to provision server with Docker
- Run `kamal deploy` to deploy/update applications
- kamal-proxy handles routing, health checks, zero-downtime switches

**GitOps Compatibility**: ⭐⭐⭐
- Push to Git → CI runs `kamal deploy`
- Designed for CI/CD integration
- Imperative model (explicit deploy commands)

**Secrets Management**:
- [kamal-secrets](https://kamal-deploy.org/docs/configuration/environment-variables/#secrets): Built-in secrets adapter
- 1Password adapter available ✨
- Secrets fetched at deploy time, not stored in Git

**Pros**:
- ✅ **Zero-downtime deploys**: Seamless container switching
- ✅ **Production-proven**: Powers 37signals' applications
- ✅ **1Password native support**: Built-in secrets adapter
- ✅ **Simple mental model**: Imperative commands, easy debugging
- ✅ **Accessory services**: Can manage databases, Redis, etc.
- ✅ **Active development**: Regular releases, good documentation
- ✅ **Provider agnostic**: Works with any SSH-accessible server

**Cons**:
- ❌ **Ruby dependency**: Requires Ruby installed locally
- ❌ **Primarily for web apps**: Less suited for infrastructure services
- ❌ **Not declarative**: Server state not fully in code
- ❌ **No built-in reverse proxy config**: Focus is on app deployment
- ❌ **Learning curve for config**: deploy.yml syntax specific to Kamal
- ❌ **Single-app focus**: Managing many services requires more config

**Resource Overhead**: Low (Docker + kamal-proxy ~50MB)

**Additional Costs**: None

### Option 6: CapRover

**Overview**: CapRover is a self-hosted PaaS (Platform as a Service) similar to Heroku. It provides a web UI for deploying applications, managing domains, and installing one-click apps. Uses Docker Swarm under the hood.

**How it works**:
- Install CapRover on server with one Docker command
- Access web UI to configure apps, domains, SSL
- Deploy via web UI, CLI, or Git webhooks
- One-click apps for common services (PostgreSQL, etc.)

**GitOps Compatibility**: ⭐⭐⭐
- Git webhook support for automatic deploys
- CLI (`caprover deploy`) for scripted deployments
- State lives on server, not fully in Git

**Secrets Management**:
- Environment variables via web UI
- App-specific environment configuration
- No built-in 1Password integration
- Secrets stored on server (encrypted at rest optional)

**Pros**:
- ✅ **Web UI**: Visual interface for management
- ✅ **One-click apps**: Easy installation of databases, services
- ✅ **Automatic HTTPS**: Let's Encrypt built-in
- ✅ **Very beginner-friendly**: Minimal Linux/Docker knowledge needed
- ✅ **No lock-in**: Apps are standard Docker containers
- ✅ **Cluster support**: Can add nodes for scaling
- ✅ **Active community**: Good documentation, Slack community

**Cons**:
- ❌ **State not in Git**: Configuration lives on server
- ❌ **Web UI dependency**: Some operations require UI
- ❌ **Docker Swarm**: Additional complexity vs plain Docker
- ❌ **Resource overhead**: CapRover itself uses ~300MB RAM
- ❌ **Less automation-friendly**: Designed for interactive use
- ❌ **Backup complexity**: Must backup CapRover config + volumes
- ❌ **Single point of failure**: CapRover app must stay healthy

**Resource Overhead**: Medium (~300MB RAM for CapRover + nginx + Docker Swarm)

**Additional Costs**: None

## Comparison Matrix

| Criteria | NixOS | Uncloud | Docker+Ansible | Docker+cloud-init | Kamal | CapRover |
|----------|-------|---------|----------------|-------------------|-------|----------|
| **Learning Curve** | High | Low | Medium | Low | Medium | Very Low |
| **Reproducibility** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐ | ⭐⭐⭐ | ⭐⭐ |
| **GitOps Support** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐ |
| **Maintenance** | Low | Low | Medium | High | Medium | Low |
| **Rollback** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐ | ⭐ | ⭐⭐⭐⭐ | ⭐⭐ |
| **Disaster Recovery** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐ | ⭐⭐⭐ | ⭐⭐ |
| **1Password Integration** | Possible | Manual | ⭐⭐⭐⭐⭐ | Manual | ⭐⭐⭐⭐⭐ | Manual |
| **Community/Docs** | ⭐⭐⭐ | ⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ |
| **Production Ready** | ⭐⭐⭐⭐⭐ | ⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ |
| **Auto-updates** | ⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐ |
| **Resource Overhead** | Minimal | Low | Low | Minimal | Low | Medium |
| **Additional Costs** | None | None | None | None | None | None |

## Secrets Management Recommendation

Based on the available options and having 1Password available:

| Approach | Recommended Secrets Solution |
|----------|------------------------------|
| NixOS | sops-nix with age encryption (1Password for master key backup) |
| Uncloud | SOPS-encrypted compose files + 1Password CLI |
| Docker+Ansible | **1Password Ansible Collection** (best integration) |
| Docker+cloud-init | 1Password CLI in provisioning scripts |
| Kamal | **Kamal 1Password secrets adapter** (built-in support) |
| CapRover | Environment variables via UI (less ideal) |

**Recommendation**: Docker+Ansible or Kamal have the best 1Password integration. For other approaches, SOPS with age encryption provides good security with secrets stored encrypted in Git.

## Backup Strategy

### PostgreSQL: pgBackRest

[pgBackRest](https://pgbackrest.org/) is a professional PostgreSQL backup solution offering:
- **Incremental backups**: Only changed blocks are backed up
- **Parallel backup/restore**: Faster operations using multiple threads
- **Compression**: Built-in LZ4/zstd compression
- **Encryption**: AES-256 encryption at rest
- **Point-in-Time Recovery (PITR)**: Restore to any point in time
- **NixOS module available**: `services.pgbackrest`

**Backup schedule**:
- Full backup: Weekly (Sunday)
- Differential backup: Daily
- WAL archiving: Continuous

**Retention**: 7 daily, 4 weekly, 2 monthly

### Application Data: Restic

[Restic](https://restic.net/) for Docker volumes and application data:
- Encrypted, deduplicated backups
- Multiple backend support
- Fast incremental backups
- NixOS module available: `services.restic.backups`

### Backup Destinations (3-2-1 Strategy)

| Destination | Type | Purpose | Cost |
|-------------|------|---------|------|
| **Hetzner Storage Box** | Offsite (cloud) | Primary offsite backup | ~€3-5/month for BX11 (1TB) 💰 |
| **Raspberry Pi + External HDD** | Offsite (home) | Secondary backup, fast local restore | One-time hardware cost |
| **Local server** | On-site | Quick restores, WAL archiving | Included |

**Hetzner Storage Box**:
- Accessible via SFTP/rsync/Restic REST server
- Located in different datacenter than VPS
- BX11: 1TB for €3.81/month

**Raspberry Pi Setup**:
- Restic REST server running on Pi
- External HDD for storage
- WireGuard tunnel for secure access
- Acts as secondary offsite + fast local restore option

### Configuration Backups

Git repository (inherent with NixOS flake approach):
- All system configuration in version control
- Full disaster recovery from Git + data backups

## Recommendation

### Chosen Approach: NixOS with Declarative Configuration

**Rationale**:
1. **Complete reproducibility**: Entire system state is declarative and version-controlled
2. **Superior disaster recovery**: Rebuild identical server from flake + data backups
3. **Atomic rollbacks**: Instant rollback to previous system generations on failure
4. **No configuration drift**: System always matches declared state
5. **Native service modules**: PostgreSQL, pgBackRest, Restic, nginx all have NixOS modules
6. **GitOps-native**: Push to Git → rebuild system, natural workflow
7. **Long-term maintainability**: Once set up, requires minimal intervention

**Trade-offs accepted**:
- Steeper initial learning curve (estimated 20-40 hours)
- Nix language requires investment to understand
- Debugging Nix errors can be challenging initially

**Implementation outline**:
```
├── flake.nix                    # Flake entry point
├── flake.lock                   # Pinned dependencies
├── hosts/
│   └── server/
│       ├── configuration.nix    # Main system config
│       ├── hardware.nix         # Hardware-specific
│       └── services/
│           ├── postgres.nix     # PostgreSQL + pgBackRest
│           ├── authentik.nix    # SSO
│           ├── nginx.nix        # Reverse proxy
│           ├── forgejo.nix
│           ├── rallly.nix
│           └── ...
├── modules/
│   ├── backup.nix               # Restic configuration
│   ├── secrets.nix              # sops-nix setup
│   └── common.nix               # Shared configuration
├── secrets/
│   └── secrets.yaml             # SOPS-encrypted secrets
└── docs/
    ├── SETUP.md
    └── adr/
```

### Alternative Approaches (Not Selected)

- **Docker+Ansible**: Good option, but NixOS offers stronger guarantees
- **Kamal**: Excellent for web app deployment, less suited for infrastructure
- **Uncloud**: Promising but not production-ready
- **Docker+cloud-init**: Too limited for ongoing maintenance
- **CapRover**: State-on-server conflicts with reproducibility goals

## Decision

**NixOS with Declarative Configuration** is selected as the server automation approach.

## Consequences

### Positive

- **Complete reproducibility**: Server can be rebuilt identically from configuration
- **Atomic updates**: System-wide upgrades with instant rollback capability
- **No drift**: Configuration in Git is always the source of truth
- **Native integrations**: PostgreSQL, pgBackRest, Restic, nginx all have first-class NixOS modules
- **Excellent GitOps**: Natural fit with `nixos-rebuild switch --flake`
- **Long-term stability**: Once configured, minimal ongoing maintenance

### Negative

- **Learning investment**: 20-40 hours to become comfortable with Nix
- **Initial setup time**: Longer than Docker-based approaches
- **Debugging complexity**: Nix error messages can be cryptic
- **Smaller community**: Fewer tutorials than Docker/Ansible

### Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Steep learning curve | Start with minimal config, iterate |
| Some services lack NixOS modules | Use `virtualisation.oci-containers` for Docker fallback |
| Secrets management complexity | Use sops-nix with age encryption |
| Provider doesn't support NixOS | Hetzner supports NixOS; use nixos-anywhere for others |

## Follow-up Actions

1. **Set up NixOS flake structure** in repository
2. **Configure sops-nix** for secrets management (1Password for master key backup)
3. **Set up deploy-rs or colmena** for remote deployment
4. **Configure pgBackRest** for PostgreSQL backups
5. **Set up Restic** with dual destinations:
   - Hetzner Storage Box (SFTP)
   - Raspberry Pi REST server (WireGuard tunnel)
6. **Document NixOS installation** in `docs/SETUP.md`
7. **Create GitHub Actions workflow** for GitOps deployment

## Additional Costs

| Item | Cost |
|------|------|
| Hetzner Storage Box BX11 (1TB) | ~€3.81/month |
| Raspberry Pi + External HDD | One-time (~€50-100) |

## References

- [NixOS Manual](https://nixos.org/manual/nixos/stable/)
- [Nix Flakes](https://nixos.wiki/wiki/Flakes)
- [sops-nix](https://github.com/Mic92/sops-nix)
- [deploy-rs](https://github.com/serokell/deploy-rs)
- [pgBackRest Documentation](https://pgbackrest.org/user-guide.html)
- [pgBackRest NixOS Module](https://search.nixos.org/options?query=pgbackrest)
- [Restic Documentation](https://restic.readthedocs.io/)
- [Restic NixOS Module](https://search.nixos.org/options?query=services.restic)
- [Hetzner Storage Box](https://www.hetzner.com/storage/storage-box)
- [nixos-anywhere](https://github.com/nix-community/nixos-anywhere)
