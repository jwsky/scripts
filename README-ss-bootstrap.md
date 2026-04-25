# Shadowsocks + SSH key bootstrap

This script configures a fresh Ubuntu server with:

- SSH public key login
- Password login disabled after the key is installed
- `shadowsocks-libev`
- Root-only Shadowsocks config permissions
- Automatic bind IP detection for NAT cloud servers

Private values are read from the private repository `jwsky/jwscript` through a
short-lived GitHub fine-grained token.

## One-line install

```bash
curl -fsSL https://raw.githubusercontent.com/jwsky/scripts/main/ss-bootstrap.sh | sudo bash -s -- default
```

If the image has `wget` but not `curl`:

```bash
wget -qO- https://raw.githubusercontent.com/jwsky/scripts/main/ss-bootstrap.sh | sudo bash -s -- default
```

The script prompts for the GitHub token. Do not pass the token as a command
line argument.

## Token permissions

Create a GitHub fine-grained personal access token:

- Repository access: only `jwsky/jwscript`
- Contents: Read-only
- Metadata: Read-only
- Expiration: 1 day or 7 days

Revoke the token after deployment if it was created only for this server.

## Profile files

The default profile is loaded from `profiles/default/` in `jwsky/jwscript`.

Required:

- `authorized_keys`
- `ss_port`
- `ss_password`

Optional:

- `ss_method`, default `chacha20-ietf`
- `ss_timeout`, default `86400`
- `ss_local_port`, default `1080`
- `ss_fast_open`, default `true`
- `bind_ip`, default `auto`

`bind_ip=auto` means:

1. If the public IP is actually on a local interface, bind that IP.
2. Otherwise bind the default route source IP, which is usually the private
   cloud VNIC IP behind NAT.
3. Fall back to `0.0.0.0` only if no local route IP can be detected.

