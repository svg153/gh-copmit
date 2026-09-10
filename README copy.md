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
- ⚡ **Model benchmarking** to compare latency and cost
- 💰 **Cost estimation** with provider and GitHub unified billing modes
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

### Basic Usage

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

### Quick Examples

```bash
# Review and commit staged changes
gh copmit

# Commit all changes with auto-push
gh copmit --all --push

# Generate commit message only (no commit)
gh copmit --dry-run
```

## 🔧 Development

### Local Installation

Symlink this folder into the gh extensions directory:

```bash
ln -s $(pwd) ~/.local/share/gh/extensions/gh-copmit
```

### Script Structure

- **Command**: `gh copmit`
- **Main script**: `gh-copmit.sh` (symlinked as `gh-copmit` for gh CLI)
- **Benchmark script**: `bench_models.sh`

## 📊 Benchmarking & Cost Analysis

Compare latency and cost across different models to find the optimal balance for your workflow.

### Quick Benchmark

```bash
./bench_models.sh 1 | tee bench-results.csv
```

### Pricing Modes

#### 1. Provider Direct Pricing

Based on provider public pricing pages (per 1k tokens):

```bash
cp prices.example.json prices.json
# Edit prices.json with input/output price per 1k tokens for each model
PRICES_FILE=prices.json ./bench_models.sh 1 | tee bench-results.csv
```

**CSV columns**: `Model,Run,Millis,Status,InChars,OutChars,EstInTokens,EstOutTokens,PriceInPer1k,PriceOutPer1k,EstCostUSD`

#### 2. GitHub Models Unified Billing

Based on GitHub's token multipliers and unified billing:

```bash
cp multipliers.example.json multipliers.json
UNIT_PRICE=0.00001 MULTIPLIERS_FILE=multipliers.json ./bench_models.sh 1 | tee bench-results-unified.csv
```

**Cost formula**:
```
token_units = in_tokens × input_multiplier + out_tokens × output_multiplier
EstCostUSD = token_units × UNIT_PRICE (default: 0.00001)
```

**CSV columns**: `Model,Run,Millis,Status,InChars,OutChars,EstInTokens,EstOutTokens,InputMult,OutputMult,UnitPrice,TokenUnits,EstCostUSD`

> 💡 **Note**: Token estimation uses a heuristic (~4 chars/token). Multipliers are available at:
> https://docs.github.com/en/billing/reference/models-multipliers-and-costs

### Updating Pricing Data

1. **GitHub Models multipliers**: Update `multipliers.json` from [GitHub Docs](https://docs.github.com/en/billing/reference/models-multipliers-and-costs)
2. **Provider pricing**: Update `prices.json` from each provider's official pricing page
3. Re-run benchmarks to compare cost vs latency trade-offs
4. Adjust default model in `gh-copmit.sh` based on your preferences

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📝 License

See [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Built with [GitHub CLI](https://github.com/cli/cli)
- Powered by [GitHub Models](https://github.com/marketplace/models)
- Follows [Conventional Commits](https://www.conventionalcommits.org/) specification

---

<p align="center">
  If you find this extension useful, consider giving it a ⭐ on <a href="https://github.com/svg153/gh-copmit">GitHub</a>!
</p>
