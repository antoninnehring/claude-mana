# Claude Mana

macOS menu-bar app that shows remaining Claude usage as two mana orbs: **Session** (5-hour window) and **Weekly**.

Requires macOS 14+. Auth uses the same OAuth token Claude Code stores in the macOS keychain — no keys in this repo.

## Build

```bash
./build.sh
open ClaudeMana.app
```

Optional local overrides live at `~/.config/claude-mana/config.json`. See `config.example.json` for the format.
