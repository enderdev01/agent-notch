# Contributing

Thanks for helping. Small, focused pull requests are the easiest to review.

## Setup

Requires macOS 14+ and Swift 6 (Xcode 16+ or the matching toolchain).

```bash
make build      # swift build -c release
make app        # build/Agent Notch.app
make run        # run the binary
```

## How changes get in

`main` is protected: nobody pushes to it directly. Every change goes through a pull request that the maintainer approves.

1. Open an issue describing the bug or idea and wait for a go-ahead.
2. Fork the repo and create a branch (`fix/short-name`, `feat/short-name`).
3. Open a pull request that links the issue (`Closes #123`). CI must pass.

## Before you open a PR

- UI strings go through `L("English text")`. Add the Spanish and German translations in `packaging/locales/<lang>.lproj/`
  and run `python3 scripts/check-strings.py` (CI runs it too).
- Keep the layers as they are: `Domain` knows nothing about UI or networking, `Infrastructure` talks to the system.
- The server must stay loopback-only and the app must not make network requests.
- Use [conventional commits](https://www.conventionalcommits.org/) (`feat:`, `fix:`, `docs:`, `chore:`).
- Do not commit secrets, certificates, or personal paths. Never include a notarization password or profile.

## Security issues

Do not file them as issues. See [SECURITY.md](SECURITY.md).

## License

By contributing you agree your work is released under the [MIT license](LICENSE).
