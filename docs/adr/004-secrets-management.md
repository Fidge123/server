# ADR-004: Secrets Management Strategy

## Status
**Accepted** – January 29, 2026

## Context

Our NixOS infrastructure requires secrets (database passwords, API keys, backup encryption keys) to be:
1. Encrypted at rest in the Git repository
2. Decryptable only on authorized machines
3. Testable in local VM environments
4. Manageable without complex key distribution

We evaluated several approaches for secrets management in NixOS.

## Decision

We will use **sops-nix** with **age** encryption for secrets management, with the following key strategy:

### Production: Dedicated Age Key (Manual Provisioning)

For the production server, we use a **dedicated age key** that is:
- Generated manually by the operator
- Stored securely in 1Password (or similar password manager)
- Provisioned to the server at `/var/lib/sops-nix/key.txt` during installation

### Testing: Committed Test Key

For VM tests, we use a **separate age key** that is:
- Committed to the repository in `keys/test.age`
- Used only for encrypting test secrets
- Never used for production secrets

## Alternatives Considered

### Option A: SSH Host Key Conversion

**Approach:** Use the server's SSH host key, converted to age format.

**Benefits:**
- No additional key to manage
- SSH key is auto-generated during NixOS installation
- Single source of identity for both SSH and secrets

**Risks:**
- Key is not known until after installation (chicken-and-egg problem)
- Key changes if server is reinstalled
- Requires running `ssh-keyscan` and conversion after each install
- Cannot encrypt secrets for a new server before first boot

**Verdict:** Rejected - The chicken-and-egg problem makes initial deployment complex.

### Option B: Dedicated Age Key (Chosen)

**Approach:** Generate a dedicated age key for each machine, provision during installation.

**Benefits:**
- Key is known before server exists
- Can pre-encrypt all secrets before first deployment
- Key survives server reinstallation if backed up
- Clear separation between SSH authentication and secrets decryption
- Easy to rotate: generate new key, re-encrypt secrets, provision

**Risks:**
- Additional key to manage and back up
- Must be securely transmitted to server during installation
- If lost and not backed up, secrets cannot be decrypted

**Verdict:** Accepted - Benefits outweigh risks when combined with proper backup.

### Option C: GPG Keys

**Approach:** Use GPG keys for sops encryption.

**Benefits:**
- Widely understood and used
- Can leverage existing GPG infrastructure

**Risks:**
- GPG is complex and has many footguns
- Key management is more complicated than age
- Larger key sizes, slower operations
- sops-nix has better age integration

**Verdict:** Rejected - Age is simpler and better integrated with sops-nix.

### Option D: HashiCorp Vault

**Approach:** Use Vault for dynamic secrets.

**Benefits:**
- Enterprise-grade secrets management
- Dynamic secret generation
- Audit logging

**Risks:**
- Significant operational overhead
- Another service to maintain and secure
- Overkill for single-server setup

**Verdict:** Rejected - Too complex for our use case.

## Implementation

### Key Hierarchy

```
keys/
├── test.age          # Test key (committed, public in repo)
└── .gitignore        # Ensures prod keys never committed

secrets/
├── secrets.yaml      # Production secrets (encrypted with prod key)
└── test.yaml         # Test secrets (encrypted with test key)
```

### .sops.yaml Configuration

```yaml
keys:
  # Production server
  - &server age1productionkeyhere...
  
  # Test/CI (committed to repo - contains no real secrets)
  - &test age1testkeyfromkeys/test.age...

creation_rules:
  # Test secrets - only test key
  - path_regex: secrets/test\.yaml$
    key_groups:
      - age:
          - *test
  
  # Production secrets - only production key
  - path_regex: secrets/secrets\.yaml$
    key_groups:
      - age:
          - *server
```

### Security Considerations

1. **Test Key Exposure:** The test key is committed to the repository. This is intentional and safe because:
   - It only encrypts test secrets (dummy values)
   - Production secrets use a separate key that is never committed
   - VM tests need deterministic decryption

2. **Production Key Backup:** The production age key MUST be:
   - Generated on a secure machine
   - Immediately backed up to 1Password
   - Never stored unencrypted on disk long-term
   - Provisioned via secure channel during installation

3. **Key Rotation:** To rotate the production key:
   1. Generate new age key
   2. Add new key to `.sops.yaml`
   3. Run `sops updatekeys secrets/secrets.yaml`
   4. Remove old key from `.sops.yaml`
   5. Provision new key to server
   6. Redeploy

## Consequences

### Positive

- Secrets are encrypted in Git (safe to push publicly)
- VM tests work without external dependencies
- Production secrets are protected by a key only on authorized machines
- Simple key management with age (single file, no expiration)

### Negative

- Production key must be manually provisioned during installation
- Key loss without backup means secrets are unrecoverable
- Two-key system requires understanding which key encrypts what

### Neutral

- Operators must learn sops/age tooling
- CI needs access to test key (already in repo)

## References

- [sops-nix documentation](https://github.com/Mic92/sops-nix)
- [age encryption](https://github.com/FiloSottile/age)
- [Mozilla SOPS](https://github.com/getsops/sops)
