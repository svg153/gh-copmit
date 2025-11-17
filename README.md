<h1 align="center">gh-copmit</h1>

<p align="center">
  <a href="https://github.com/svg153/gh-copmit/releases"><img src="https://img.shields.io/github/release/svg153/gh-copmit.svg" alt="Latest Release"></a>
  <a href="https://github.com/svg153/gh-copmit/blob/main/LICENSE"><img src="https://img.shields.io/github/license/svg153/gh-copmit" alt="License"></a>
  <a href="https://github.com/cli/cli"><img src="https://img.shields.io/badge/gh-extension-blue" alt="gh extension"></a>
</p>

<h4 align="center">🤖 AI-powered Conventional Commits using GitHub Models</h4>

<p align="center">
  A <code>gh</code> CLI extension that generates <a href="https://www.conventionalcommits.org/">Conventional Commit</a> messages and bodies automatically using GitHub Models AI.
</p>

---

## ✨ Features

- 🎯 **AI-generated commits** using GitHub Models (`gh models`)
- 📝 **Conventional Commits** format (feat, fix, docs, etc.)
- 🌍 **Multi-language support** (English, Spanish, and more)
- 🔍 **Dry-run mode** to preview commits before creating them
- 🚀 **Auto-push** option after committing

## 📦 Installation

```bash
gh extension install svg153/gh-copmit
```

> **Prerequisites:**
> - [GitHub CLI](https://github.com/cli/cli) authenticated
> - `gh models` extension (auto-installed with `--yes` flag)
> - `jq` (optional, for robust JSON parsing)

## 🚀 Usage

```bash
# Show help
gh copmit --help

# Stage all changes and create commit (English, default model)
gh copmit --all

# Preview commit message (dry-run)
gh copmit --all --dry-run

# Create commit in Spanish
gh copmit --all --lang es

# Create commit and push
gh copmit --all --push
```

## 📁 Repository Files

- **`gh-copmit.sh`** - Main extension script that generates AI-powered commit messages
- **`.gitignore`** - Git ignore rules for the project

For additional scripts, documentation, and examples, check the local repository or future releases.

## 🔧 Development

Local installation for development:

```bash
ln -s $(pwd) ~/.local/share/gh/extensions/gh-copmit
```

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 🙏 Acknowledgments

- Built with [GitHub CLI](https://github.com/cli/cli)
- Powered by [GitHub Models](https://github.com/marketplace/models)
- Follows [Conventional Commits](https://www.conventionalcommits.org/) specification

---

<p align="center">
  If you find this extension useful, consider giving it a ⭐ on <a href="https://github.com/svg153/gh-copmit">GitHub</a>!
</p>
