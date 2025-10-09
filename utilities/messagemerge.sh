#!/usr/bin/env bash
set -euo pipefail

MSG="${1:-update the changelog merge master hot-fix}"

# Comprobar repo
GIT_DIR=$(git rev-parse --git-dir 2>/dev/null) || { echo "No es un repo git"; exit 1; }

CHANGELOG="./CHANGELOG.md"

git checkout master

git merge --no-ff --no-commit hot-fix

# Usamos HEAD como MERGE_HEAD para no introducir un SHA inválido
    #HEAD_SHA=$(git rev-parse HEAD)

# Escribimos MERGE_HEAD y MERGE_MSG para simular un merge en curso
    #printf "%s\n" "$HEAD_SHA" > "$GIT_DIR/MERGE_HEAD"
    #printf "%s\n" "$MSG" > "$GIT_DIR/MERGE_MSG"

#echo "Simulado 'merge in progress'. Mensaje escrito en $GIT_DIR/MERGE_MSG"
#echo "Ahora abre/actualiza Visual Studio Source Control para ver el pre-commit."