# GitHub Models Billing Reference (Minimal)

This file explains how `bench_models.sh` can estimate cost under GitHub Models unified billing without duplicating provider data.

## Why this matters
`gh models run` usage for paid tiers is billed via token units (GitHub unified SKU) not necessarily the provider’s raw per-token prices. Future changes may add or remove models or adjust multipliers.

## Pricing Modes Supported
1. Provider pricing (`PRICES_FILE`): per 1k input/output token USD values.
2. Unified billing (`MULTIPLIERS_FILE`): model-specific `input_multiplier` and `output_multiplier` plus a universal `UNIT_PRICE` (default `0.00001`).

The script prefers provider pricing if both env files are set, otherwise falls back to multipliers when available.

## Updating Multipliers
1. Visit: https://docs.github.com/en/billing/reference/models-multipliers-and-costs
2. For each model you benchmark, record:
   - `input_multiplier`
   - `output_multiplier` (use `null` if “N/A” in the table)
   - `source` (the URL above)
3. Save changes to `multipliers.json`.
4. Run:
```bash
UNIT_PRICE=0.00001 MULTIPLIERS_FILE=multipliers.json ./bench_models.sh 3 | tee bench-results-unified.csv
```
5. Compare `Millis` (latency) vs `EstCostUSD`.

## Regenerating prices.json (Provider Pricing)
1. Open each provider’s official pricing page (e.g., OpenAI, Mistral, etc.).
2. Convert per‑1M token prices to per‑1K by dividing by 1000.
3. Update entries in `prices.json` with `in_per_1k` and `out_per_1k` and a `source` URL.
4. Run:
```bash
PRICES_FILE=prices.json ./bench_models.sh 3 | tee bench-results-provider.csv
```

## Decision Guidance
- Prefer unified billing mode when optimizing cost under GitHub’s own metered usage.
- Use provider pricing for cross-platform comparisons or when bringing your own API keys.

## No Duplication Rule
This doc intentionally omits raw tables—consult the linked pages as the single source of truth.

## Troubleshooting
- Empty cost column: multipliers or prices missing for a model.
- Newline issues in CSV: ensure JSON values are numbers or `null` (no strings like `"N/A"`).
- Large outputs inflating token units: consider adding a smaller diff sample if benchmarking purely latency.

## Next Review
Set a calendar reminder (e.g., monthly) to refresh `multipliers.json` and `prices.json` to catch model changes or new entries.
