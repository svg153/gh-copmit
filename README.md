# gh-copmit

A `gh` CLI extension to generate Conventional Commit messages and bodies using GitHub Models (`gh models`).

- Command: `gh copmit`
- Script file: `gh-copmit.sh` (symlinked as `gh-copmit` for gh)
- Install (local dev): symlink this folder into `~/.local/share/gh/extensions/gh-copmit/`.

## Usage

- Show help:
  gh copmit --help

- Stage all changes and propose commit (dry-run):
  gh copmit --all --dry-run

- Create commit (English, default model):
  gh copmit --all

- Create commit (Spanish):
  gh copmit --all --lang es

- Push after committing:
  gh copmit --push

## Requirements

- GitHub CLI authenticated
- `gh models` extension installed (script can auto-install with `--yes`)
- jq (optional, for robust JSON parsing)
