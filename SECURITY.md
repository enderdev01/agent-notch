# Security policy

## Reporting a vulnerability

Please **do not open a public issue** for a security problem. Use GitHub's private reporting instead:
[Report a vulnerability](https://github.com/enderdev01/agent-notch/security/advisories/new).

Include what you found, how to reproduce it, and the version (menu bar item, or `CFBundleShortVersionString`).
You can expect a first answer within 7 days. Fixes ship in a new release and are credited in its notes unless you prefer otherwise.

## Supported versions

Only the latest release receives fixes.

## Threat model

Agent Notch runs entirely on your Mac and sends nothing to the network.

- The hook server binds to `127.0.0.1` only (default port `47823`) and rejects non-loopback connections.
- Hook events and approval requests are plain local HTTP with no authentication. **Any process running as you can post to it**,
  including spoofing an event or answering an *Allow / Deny* card. This is a known limitation of a local, unauthenticated bridge;
  reports that need local code execution as the same user are out of scope unless they cross a privilege boundary.
- Release builds are ad-hoc signed and not notarized unless the release notes say otherwise.
- `scripts/install.sh` edits the agents' own hook configuration (Claude Code, Codex, Gentle Shell). `scripts/uninstall.sh` reverts it.

In scope: remote or cross-user access to the server, parsing bugs in the HTTP/payload decoders, the installer writing outside the
agents' config files, anything that makes the app send data off the machine.
