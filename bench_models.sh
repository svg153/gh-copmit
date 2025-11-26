#!/usr/bin/env bash
set -euo pipefail

# Benchmark several GitHub Models for the same prompt/context.
# Usage: ./bench_models.sh [runs]
# Default runs = 1
#
# Outputs CSV with columns (dynamic based on pricing mode):
# Base columns:
#   Model,Run,Millis,Status,InChars,OutChars,EstInTokens,EstOutTokens
# Provider price mode (PRICES_FILE): adds
#   PriceInPer1k,PriceOutPer1k,EstCostUSD
# GitHub unified billing mode (MULTIPLIERS_FILE): adds
#   InputMult,OutputMult,UnitPrice,TokenUnits,EstCostUSD
#
# Pricing modes (choose one):
# 1. Per-model provider pricing (PRICES_FILE): JSON mapping model-> { in_per_1k, out_per_1k, source }
# 2. GitHub Models unified billing (MULTIPLIERS_FILE): JSON mapping model-> { input_multiplier, output_multiplier, source }
#    Cost formula: token_units = in_tokens*input_multiplier + out_tokens*output_multiplier
#                  total_cost = token_units * UNIT_PRICE (default 0.00001 USD per token unit)
# NOTE: If BOTH files provided, provider pricing takes precedence.

RUNS=${1:-1}

# timeout command optional
if command -v timeout >/dev/null 2>&1; then
  TIMEOUT_PREFIX=(timeout 45s)
else
  TIMEOUT_PREFIX=()
fi

MODELS=(
  "openai/gpt-5-nano"
  "openai/gpt-5-mini"
  "openai/gpt-4.1-nano"
  "openai/gpt-4o-mini"
  "microsoft/phi-4-mini-instruct"
  "mistral-ai/mistral-small-2503"
)

PROMPT_ES='You are an assistant that writes clear, helpful commit messages.
Use the staged git changes provided via STDIN as context.

Requirements:
- Prefer Conventional Commits (type(scope)!: subject) when possible
- Subject must be <= 72 chars and MUST NOT end with a period
- Body should explain the why and the what in concise bullet points
- Include BREAKING CHANGE: in the body if applicable
- Do not invent changes not present in the diff

Return ONLY valid JSON in this exact shape:
{"subject": "...", "body": "..."}
'

# A small fixed diff-like context (kept short to reduce token costs)
CONTEXT=$(cat <<'CTX'
REPO: sample-repo
BRANCH: feature/xyz
BASE_BRANCH: main

STAGED FILES (name-status):
M	README.md
A	src/main.py

SUMMARY (numstat):
10	2	README.md
120	0	src/main.py

DIFF (unified=1, truncated to 200 lines):
--- a/README.md
+++ b/README.md
@@
-Old line
+New line explaining feature xyz
--- /dev/null
+++ b/src/main.py
@@
+def add(a, b):
+    return a + b
+
+if __name__ == "__main__":
+    print(add(2, 3))
CTX
)

get_price() {
  local model="$1" field="$2"
  if [[ -n "${PRICES_FILE:-}" && -f "$PRICES_FILE" ]] && command -v jq >/dev/null 2>&1; then
    jq -r --arg m "$model" --arg f "$field" '.[$m][$f] // empty' "$PRICES_FILE"
  else
    echo ""
  fi
}

get_multiplier() {
  local model="$1" field="$2"
  if [[ -n "${MULTIPLIERS_FILE:-}" && -f "$MULTIPLIERS_FILE" ]] && command -v jq >/dev/null 2>&1; then
    jq -r --arg m "$model" --arg f "$field" '.[$m][$f] // empty' "$MULTIPLIERS_FILE"
  else
    echo ""
  fi
}

# rough token estimate: ~4 chars per token
est_tokens() {
  local chars="$1"
  awk -v c="$chars" 'BEGIN { printf("%d", (c+3)/4) }'
}

if [[ -n "${PRICES_FILE:-}" && -f "$PRICES_FILE" ]]; then
  header="Model,Run,Millis,Status,InChars,OutChars,EstInTokens,EstOutTokens,PriceInPer1k,PriceOutPer1k,EstCostUSD"
elif [[ -n "${MULTIPLIERS_FILE:-}" && -f "$MULTIPLIERS_FILE" ]]; then
  header="Model,Run,Millis,Status,InChars,OutChars,EstInTokens,EstOutTokens,InputMult,OutputMult,UnitPrice,TokenUnits,EstCostUSD"
else
  header="Model,Run,Millis,Status,InChars,OutChars,EstInTokens,EstOutTokens"
fi
printf "%s\n" "$header"
for model in "${MODELS[@]}"; do
  for ((i=1;i<=RUNS;i++)); do
    start=$(date +%s%3N)
    if out=$(printf '%s\n' "$CONTEXT" | GH_HOST=github.com "${TIMEOUT_PREFIX[@]}" gh models run "$model" "$PROMPT_ES" 2>/dev/null); then
      status=OK
    else
      status=FAIL
    fi
    end=$(date +%s%3N)
    millis=$((end - start))
    in_chars=$(( ${#CONTEXT} + ${#PROMPT_ES} ))
    out_chars=${#out}
    in_tok=$(est_tokens "$in_chars")
    out_tok=$(est_tokens "$out_chars")
    if [[ -n "${PRICES_FILE:-}" && -f "$PRICES_FILE" ]]; then
      pin=$(get_price "$model" in_per_1k | tr -d '\r\n')
      pout=$(get_price "$model" out_per_1k | tr -d '\r\n')
      if [[ -n "$pin" && -n "$pout" ]]; then
        cost=$(awk -v it="$in_tok" -v ot="$out_tok" -v a="$pin" -v b="$pout" 'BEGIN { printf("%.6f", (it/1000.0)*a + (ot/1000.0)*b) }')
      else
        pin=""
        pout=""
        cost=""
      fi
      printf "%s,%d,%d,%s,%d,%d,%d,%d,%s,%s,%s\n" \
        "$model" "$i" "$millis" "$status" "$in_chars" "$out_chars" "$in_tok" "$out_tok" "$pin" "$pout" "$cost"
    elif [[ -n "${MULTIPLIERS_FILE:-}" && -f "$MULTIPLIERS_FILE" ]]; then
      im=$(get_multiplier "$model" input_multiplier | tr -d '\r\n')
      om=$(get_multiplier "$model" output_multiplier | tr -d '\r\n')
      # Treat missing multiplier as 0 (e.g., output N/A)
      [[ -z "$im" || "$im" == "N/A" ]] && im=0
      [[ -z "$om" || "$om" == "N/A" ]] && om=0
      unit_price=${UNIT_PRICE:-0.00001}
      # token_units = in_tok*im + out_tok*om
      token_units=$(awk -v it="$in_tok" -v ot="$out_tok" -v im="$im" -v om="$om" 'BEGIN { printf("%.6f", it*im + ot*om) }')
      cost=""
      if awk "BEGIN {exit !(('$im' + '$om') > 0)}"; then
        cost=$(awk -v tu="$token_units" -v up="$unit_price" 'BEGIN { printf("%.6f", tu*up) }')
      fi
      printf "%s,%d,%d,%s,%d,%d,%d,%d,%s,%s,%s,%s,%s\n" \
        "$model" "$i" "$millis" "$status" "$in_chars" "$out_chars" "$in_tok" "$out_tok" "$im" "$om" "$unit_price" "$token_units" "$cost"
    else
      printf "%s,%d,%d,%s,%d,%d,%d,%d\n" \
        "$model" "$i" "$millis" "$status" "$in_chars" "$out_chars" "$in_tok" "$out_tok"
    fi
    # brief pause to avoid rate spikes
    sleep 0.5
  done
done
