#!/usr/bin/env bash
set -euo pipefail

# estar en el repo (o checkout ya hecho)
if ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo "ERROR: no parece un repositorio git. Abortando."
  exit 1
fi

echo "Valor actual (merge.ours.driver): $(git config --local --get merge.ours.driver || echo '<no definido>')"
echo "Configurando merge.ours.driver=true (ámbito local)..."
git config --local merge.ours.driver true
echo "Nuevo valor (merge.ours.driver): $(git config --local --get merge.ours.driver)"

# Si el runner necesita, descomenta:
# git config --global --add safe.directory "$(pwd)"
