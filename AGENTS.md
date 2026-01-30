# Agent Instructions

## Planning & Documentation

- Always plan your next steps. Write down the plan in a `PLAN.md` file. Before executing the plan, the user MUST review and approve your plan.
- Document architectural and technical decision as ADRs in the `docs/adr` folder.
- Keep `README.md` and `AGENTS.md` updated.
- Every manual step needs to be defined in `docs/SETUP.md`

## Validation & Testing

- Every step needs to be validated in a local VM setup.
- Use NixOS VM tests (`nixosTest`) for automated validation (see [ADR-002](docs/adr/002-local-vm-testing-strategy.md))
- Run `nix flake check` before committing changes
- Create a test file in `tests/` for each implementation phase
- Tests should verify:
  - Services start correctly
  - Configuration is applied as expected
  - Backups work (where applicable)
  - Secrets are available (where applicable)

## Multi-Architecture Support

- Support both x86_64-linux and aarch64-linux (ARM)
- Test ARM configurations locally on Apple Silicon Mac using `server-arm-vm`
- Test x86_64 configurations on Linux or in CI
- Architecture-specific configurations:
  - `hosts/server-x86/` - x86_64-linux server configuration
  - `hosts/server-arm/` - aarch64-linux server configuration
  - `modules/server-common.nix` - Shared configuration for both architectures

## NixOS-Specific Guidelines

- Use Flakes for reproducibility
- Pin all dependencies in `flake.lock`
- Organize configuration by service in `hosts/server-*/services/`
- Use NixOS modules in `modules/` for reusable configuration
- Encrypt secrets with sops-nix; never commit plaintext secrets

## Backup Configuration

- Local backup is always enabled
- Remote destinations (Storage Box, Raspberry Pi) are optional
- Each backup destination should be independently testable
