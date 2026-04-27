# jwscript bootstrap

One-liner to deploy on a fresh Ubuntu host:

```bash
curl -fsSL https://raw.githubusercontent.com/jwsky/scripts/main/bootstrap.sh | sudo bash
```

If `curl` is missing on a minimal image:

```bash
wget -qO- https://raw.githubusercontent.com/jwsky/scripts/main/bootstrap.sh | sudo bash
```

The bootstrap asks for a GitHub fine-grained personal access token (scope:
`jwsky/jwscript`, Contents read-only), streams the private payload into
`/dev/shm`, and execs the menu. Pick a number, that script runs.
