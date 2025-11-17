#!/usr/bin/env bash
set -euo pipefail

# gh-copmit: Generate a Conventional Commit message and body using GitHub Models via gh CLI
# Usage: gh copmit [options]
# This script is discovered by gh CLI because it's named gh-<name> and is on PATH.

# Defaults
# Use a fast and low-cost model by default (based on local benchmark). Override with GH_COMMIT_MODEL.
MODEL_DEFAULT="${GH_COMMIT_MODEL:-openai/gpt-4.1-nano}"
LANG_DEFAULT="${GH_COMMIT_LANG:-en}"
PUSH_DEFAULT="false"
AUTO_INSTALL_DEFAULT="false"

print_help() {
  cat <<'EOF'
Usage: gh copmit [options]

Generates a high-quality Conventional Commit message and body from your STAGED changes
using GitHub Models (gh models) and creates the commit for you.

Options:
  -m, --model ID          Model ID to use (default: $GH_COMMIT_MODEL or openai/gpt-4.1-nano)
  -a, --all               Stage all changes (git add -A) before generating
      --push              Push after committing
      --dry-run           Show proposed commit without creating it
      --lang {en|es}      Language for the commit message (default: $GH_COMMIT_LANG or en)
      --no-conventional   Do not enforce Conventional Commits format
      --yes               Auto-install gh models extension if missing
  -h, --help              Show this help and exit

Environment:
  GH_COMMIT_MODEL         Default model id
  GH_COMMIT_LANG          Default language (en|es)

Examples:
  gh copmit --all --push
  gh copmit -m openai/gpt-4.1-nano --dry-run
  gh copmit --lang es
EOF
}

info()  { echo -e "\033[34mℹ\033[0m $*"; }
warn()  { echo -e "\033[33m⚠\033[0m $*"; }
error() { echo -e "\033[31m✖\033[0m $*" >&2; }
ok()    { echo -e "\033[32m✓\033[0m $*"; }

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || { error "Missing required command: $1"; exit 1; }
}

ensure_gh_models() {
  if gh models list >/dev/null 2>&1; then
    return 0
  fi
  if [[ "$AUTO_INSTALL" == "true" ]]; then
    info "Installing gh models extension..."
    gh extension install github/gh-models >/dev/null
  else
    error "gh models extension not found. Install it first: gh extension install github/gh-models"
    exit 1
  fi
}

in_git_repo() {
  git rev-parse --show-toplevel >/dev/null 2>&1
}

has_staged_changes() {
  # return 0 if any staged files
  [[ -n "$(git diff --staged --name-only)" ]]
}

collect_context() {
  local max_diff_lines="${MAX_DIFF_LINES:-3000}"
  local repo_name branch base_branch
  repo_name=$(basename "$(git rev-parse --show-toplevel)")
  branch=$(git branch --show-current 2>/dev/null || echo "")
  base_branch=${BASE_BRANCH:-main}

  {
    echo "REPO: $repo_name"
    echo "BRANCH: ${branch:-N/A}"
    echo "BASE_BRANCH: $base_branch"
    echo
    echo "STAGED FILES (name-status):"
    git diff --staged --name-status
    echo
    echo "SUMMARY (numstat):"
    git diff --staged --numstat
    echo
    echo "DIFF (unified=1, truncated to $max_diff_lines lines):"
    git diff --staged --unified=1 --no-color | head -n "$max_diff_lines"
  } | sed -e 's/\t/    /g'
}

build_prompt() {
  local lang="$1" conventional="$2"
  if [[ "$lang" == "es" ]]; then
    cat <<'PROMPT'
Eres un asistente que escribe mensajes de commit claros y útiles.
Usa el contexto de cambios de git que te paso por STDIN.

Requisitos:
- Si es posible, sigue el formato Conventional Commits (tipo(scope)!: asunto)
- El asunto (subject) debe tener <= 72 caracteres y no terminar con punto
- El cuerpo (body) debe explicar el porqué y el qué, en viñetas concisas
- Incluye BREAKING CHANGE: en el cuerpo si aplica
- No inventes cambios que no estén en el diff

Devuelve SOLO JSON válido con esta forma exacta:
{"subject": "...", "body": "..."}
PROMPT
  else
    cat <<'PROMPT'
You are an assistant that writes clear, helpful commit messages.
Use the staged git changes provided via STDIN as context.

Requirements:
- Prefer Conventional Commits (type(scope)!: subject) when possible
- Subject must be <= 72 chars and MUST NOT end with a period
- Body should explain the why and the what in concise bullet points
- Include BREAKING CHANGE: in the body if applicable
- Do not invent changes not present in the diff

Return ONLY valid JSON in this exact shape:
{"subject": "...", "body": "..."}
PROMPT
  fi
}

parse_json() {
  local raw="$1"
  if command -v jq >/dev/null 2>&1; then
    subject=$(printf '%s' "$raw" | jq -r '.subject // empty')
    body=$(printf '%s' "$raw" | jq -r '.body // empty')
  else
    # naive fallback: first line after opening brace as subject
    subject=$(printf '%s' "$raw" | sed -n 's/.*"subject"\s*:\s*"\(.*\)".*/\1/p' | head -n1)
    body=$(printf '%s' "$raw" | sed -n 's/.*"body"\s*:\s*"\(.*\)".*/\1/p' | head -n1 | sed 's/\\n/\n/g')
  fi
  [[ -n "${subject:-}" ]]
}

# ------------------
# Main
# ------------------
MODEL="$MODEL_DEFAULT"
LANG="$LANG_DEFAULT"
PUSH="$PUSH_DEFAULT"
AUTO_INSTALL="$AUTO_INSTALL_DEFAULT"
CONVENTIONAL="true"
DRY_RUN="false"
STAGE_ALL="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -m|--model) MODEL="$2"; shift 2 ;;
    --lang) LANG="$2"; shift 2 ;;
    --push) PUSH="true"; shift ;;
    --dry-run) DRY_RUN="true"; shift ;;
    --all|-a) STAGE_ALL="true"; shift ;;
    --no-conventional) CONVENTIONAL="false"; shift ;;
    --yes) AUTO_INSTALL="true"; shift ;;
    -h|--help) print_help; exit 0 ;;
    *) error "Unknown option: $1"; print_help; exit 1 ;;
  esac
done

need_cmd git
need_cmd gh
ensure_gh_models

if ! in_git_repo; then
  error "Not inside a git repository"
  exit 1
fi

if [[ "$STAGE_ALL" == "true" ]]; then
  info "Staging all changes (git add -A)"
  git add -A
fi

if ! has_staged_changes; then
  error "No staged changes found. Stage files or pass --all"
  exit 1
fi

info "Collecting context from staged changes..."
context=$(collect_context)

prompt=$(build_prompt "$LANG" "$CONVENTIONAL")

info "Asking model ($MODEL) to generate commit message..."
set +e
raw_out=$(printf '%s\n' "$context" | gh models run "$MODEL" "$prompt")
rc=$?
set -e
if [[ $rc -ne 0 ]]; then
  error "Model request failed (exit $rc). Ensure gh is authenticated for GitHub Models."
  exit $rc
fi

if ! parse_json "$raw_out"; then
  warn "Model did not return expected JSON. Falling back to heuristic parsing."
  # heuristic: first non-empty line is subject, rest is body
  subject=$(printf '%s' "$raw_out" | sed '1,/\S/p;d' | head -n1)
  body=$(printf '%s' "$raw_out" | tail -n +2)
fi

if [[ -z "${subject:-}" ]]; then
  error "Could not extract subject from model output"
  printf '\n--- Raw output ---\n%s\n' "$raw_out" >&2
  exit 1
fi

# Trim subject length to 72 chars hard-limit just in case
subject=$(printf '%.72s' "$subject")

if [[ "$DRY_RUN" == "true" ]]; then
  ok "Dry-run. Proposed commit:"
  echo "Subject: $subject"
  echo "Body:\n$body"
  exit 0
fi

info "Creating commit..."
if [[ -n "${body:-}" ]]; then
  git commit -m "$subject" -m "$body"
else
  git commit -m "$subject"
fi
ok "Commit created"

if [[ "$PUSH" == "true" ]]; then
  info "Pushing..."
  git push
  ok "Pushed"
fi
