#!/usr/bin/env bash
set -euo pipefail

MSG="${1:-hola este es un pre commit}"

# Comprobar que estamos en un repo
git rev-parse --git-dir >/dev/null 2>&1 || { echo "No es un repo git"; exit 1; }

# Stagea los cambios (como git add .)
git add -A

# Crea un objeto tree del index actualmente staged
TREE=$(git write-tree)

# Padre = HEAD
PARENT=$(git rev-parse HEAD)

# Crea un commit temporal que tiene como padre a HEAD (no crea refs, solo objeto)
COMMIT_TMP=$(echo "precommit-temp" | git commit-tree "$TREE" -p "$PARENT")

# Ejecuta merge que no hace commit pero genera .git/MERGE_MSG y estado de merge
git merge --no-ff --no-commit "$COMMIT_TMP"

# Sobrescribe el mensaje de merge con el mensaje deseado
printf "%s\n" "$MSG" > .git/MERGE_MSG

# Asegura que los cambios estén staged (para que VS los muestre como listos)
git add -A

echo "Pre-commit preparado. Mensaje en .git/MERGE_MSG:"
cat .git/MERGE_MSG
echo "Ahora abre Visual Studio (o refresca Source Control) para ver el pre-commit."
