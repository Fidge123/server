# ADR-002: Local VM Testing Strategy

## Status
**Accepted** – January 29, 2026

## Context

As part of implementing the NixOS-based infrastructure (see [ADR-001](001-server-automation-approach.md)), we need a reliable way to validate configuration changes before deploying to production servers.

### Requirements

1. **Every implementation phase must be validated** before proceeding
2. **Tests should be automated** to enable CI/CD integration
3. **Fast feedback loop** for development iteration
4. **Realistic testing** that catches configuration errors
5. **Works locally and in CI** (GitHub Actions)

### Decision Drivers

1. Catch configuration errors before production deployment
2. Enable confident refactoring of NixOS configuration
3. Provide documentation through test specifications
4. Support GitOps workflow with automated validation

## Considered Options

### Option 1: NixOS VM Tests (nixosTest)

**Overview**: Use NixOS's built-in testing framework that spawns QEMU VMs and runs test scripts.

**How it works**:
```nix
pkgs.nixosTest {
  name = "test-name";
  nodes.server = { config, pkgs, ... }: {
    imports = [ ./configuration.nix ];
  };
  testScript = ''
    server.start()
    server.wait_for_unit("multi-user.target")
    server.succeed("systemctl is-active postgresql")
  '';
}
```

**Pros**:
- ✅ Native NixOS integration
- ✅ Full system testing (not just unit tests)
- ✅ Deterministic and reproducible
- ✅ Can test multi-node scenarios
- ✅ Works in CI without special setup
- ✅ Tests are declarative and version-controlled

**Cons**:
- ❌ Slow startup (full VM boot)
- ❌ Resource intensive (RAM, CPU)
- ❌ QEMU required (works on Linux, challenging on macOS)

### Option 2: nixos-rebuild build-vm

**Overview**: Build a VM image from the configuration and run it interactively.

**How it works**:
```bash
nixos-rebuild build-vm --flake .#server
./result/bin/run-server-vm
```

**Pros**:
- ✅ Quick way to test configuration
- ✅ Interactive debugging possible
- ✅ Same configuration as production

**Cons**:
- ❌ Manual validation (not automated)
- ❌ Not suitable for CI
- ❌ No programmatic assertions

### Option 3: microvm.nix

**Overview**: Lightweight VM framework using cloud-hypervisor or firecracker for fast startup.

**How it works**:
```nix
{
  microvm.vms.test-server = {
    config = { ... }: {
      imports = [ ./configuration.nix ];
    };
  };
}
```

**Pros**:
- ✅ Very fast boot times (~1 second)
- ✅ Lower resource usage
- ✅ Can integrate with nixosTest

**Cons**:
- ❌ Additional dependency to manage
- ❌ Less mature than standard VM tests
- ❌ Some features may not work (GPU, etc.)

### Option 4: Container-based Testing

**Overview**: Use NixOS containers or systemd-nspawn for testing.

**Pros**:
- ✅ Very fast
- ✅ Low resource usage

**Cons**:
- ❌ Not full system testing (shared kernel)
- ❌ Some services behave differently in containers
- ❌ Not representative of production

## Comparison Matrix

| Criteria | nixosTest | build-vm | microvm.nix | Containers |
|----------|-----------|----------|-------------|------------|
| **Automation** | ⭐⭐⭐⭐⭐ | ⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ |
| **Speed** | ⭐⭐ | ⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| **Realism** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐ |
| **CI Compatibility** | ⭐⭐⭐⭐⭐ | ⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| **Debugging** | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐ |
| **Learning Curve** | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐ | ⭐⭐⭐⭐ |
| **Maturity** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐ |

## Decision

**Hybrid Approach**: Use NixOS VM Tests (nixosTest) for automated CI validation and `build-vm` for local development/debugging.

### Implementation

```
tests/
├── lib.nix              # Shared test utilities
├── phase-1-flake.nix    # Basic flake structure test
├── phase-2-secrets.nix  # sops-nix secrets test
├── phase-3-deploy.nix   # deploy-rs configuration test
├── phase-4-postgres.nix # PostgreSQL + pgBackRest test
├── phase-5-restic.nix   # Restic backup test
└── integration.nix      # Full system integration test
```

### Test Structure

Each phase test follows this pattern:

```nix
# tests/phase-4-postgres.nix
{ pkgs, self, ... }:
pkgs.nixosTest {
  name = "phase-4-postgres";
  
  nodes.server = { config, pkgs, ... }: {
    imports = [ 
      self.nixosModules.server
      # Test-specific overrides
    ];
    
    # Disable external dependencies for testing
    backup.storageBox.enable = false;
    backup.raspberryPi.enable = false;
  };

  testScript = ''
    server.start()
    server.wait_for_unit("postgresql.service")
    
    # Verify PostgreSQL is running
    server.succeed("sudo -u postgres psql -c 'SELECT 1'")
    
    # Verify pgBackRest configuration
    server.succeed("sudo -u postgres pgbackrest check")
    
    # Run a backup
    server.succeed("sudo -u postgres pgbackrest backup --type=full")
    
    # Verify backup exists
    server.succeed("sudo -u postgres pgbackrest info | grep -q 'full backup'")
  '';
}
```

### Integration with Flake

```nix
# flake.nix
{
  outputs = { self, nixpkgs, ... }: {
    checks.x86_64-linux = {
      phase-1-flake = import ./tests/phase-1-flake.nix { 
        inherit pkgs self; 
      };
      phase-2-secrets = import ./tests/phase-2-secrets.nix { 
        inherit pkgs self; 
      };
      # ... more tests
      
      # Run all tests
      all = pkgs.runCommand "all-tests" {} ''
        echo "All tests passed"
        touch $out
      '';
    };
  };
}
```

### Local Development Workflow

```bash
# Quick validation (syntax and basic evaluation)
nix flake check

# Run specific phase test
nix build .#checks.x86_64-linux.phase-4-postgres -L

# Interactive VM for debugging
nixos-rebuild build-vm --flake .#server
./result/bin/run-server-vm

# Run all tests
nix flake check -L
```

### CI Workflow (GitHub Actions)

```yaml
name: Validate
on: [push, pull_request]
jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: cachix/install-nix-action@v24
      - uses: cachix/cachix-action@v12
        with:
          name: self-hosted
      - run: nix flake check -L
```

## Consequences

### Positive

- **Automated validation**: Every change is tested before deployment
- **Confidence**: Catch configuration errors before production
- **Documentation**: Tests serve as executable specifications
- **GitOps ready**: CI validates every push
- **Reproducible**: Tests are deterministic

### Negative

- **CI duration**: VM tests take 5-15 minutes per phase
- **Resource requirements**: Requires Linux runner with KVM
- **macOS limitations**: VM tests don't run natively on macOS
- **Initial setup**: Writing comprehensive tests takes time

### Mitigations

| Challenge | Mitigation |
|-----------|------------|
| Slow CI | Use Cachix for caching; parallelize independent tests |
| macOS dev | Use `nix flake check` for basic validation; full tests in CI |
| Test maintenance | Keep tests focused; use shared utilities |

## Follow-up Actions

1. Create `tests/lib.nix` with shared test utilities
2. Implement phase tests as each phase is completed
3. Set up Cachix cache for faster CI builds
4. Create GitHub Actions workflow for automated testing

## References

- [NixOS Testing Documentation](https://nixos.org/manual/nixos/stable/#sec-nixos-tests)
- [NixOS Test Examples](https://github.com/NixOS/nixpkgs/tree/master/nixos/tests)
- [microvm.nix](https://github.com/astro/microvm.nix)
- [GitHub Actions for Nix](https://github.com/cachix/install-nix-action)
