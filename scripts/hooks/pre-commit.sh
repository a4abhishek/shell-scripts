#!/usr/bin/env bash
set -euo pipefail

echo "Running pre-commit checks..."

# Stash any changes not being committed
git stash -q --keep-index

# Trap to restore stashed changes even if checks fail
trap 'git stash pop -q 2>/dev/null || true' EXIT

# Run our checks
make format-check || { echo "❌ Format check failed. Run 'make format' to fix."; exit 1; }
make shellcheck || { echo "❌ Shellcheck failed."; exit 1; }
make custom-checks || { echo "❌ Custom checks failed."; exit 1; }
make test || { echo "❌ Tests failed."; exit 1; }

echo "✅ All checks passed!"
