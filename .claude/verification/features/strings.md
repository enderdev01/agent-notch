# Localized strings

`strings` runs `python3 scripts/check-strings.py` (L("...") keys vs packaging/locales/{en,es,de}.lproj). Never pass `--sync-en`.

| Input | Observed output | Exit |
|---|---|---|
| `strings` | `ok python3 scripts/check-strings.py` / `ok: 89 strings in 3 languages` | 0 |

Failure path (a missing key) was not exercised: it would require editing locale files.
