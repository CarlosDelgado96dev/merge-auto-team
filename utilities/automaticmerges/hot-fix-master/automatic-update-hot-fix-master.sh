#!/usr/bin/env bash
set -euo pipefail

GIT_DIR=$(git rev-parse --git-dir 2>/dev/null) || { echo "No es un repo git"; exit 1; }

CHANGELOG="./CHANGELOG.md"

git fetch
echo "Comando git fetch realizado correctamente"

increment_version() {
  if command -v jq >/dev/null 2>&1; then
    last_version=$(jq -r '.version' package.json 2>/dev/null)
  else
    last_version=$(grep '"version"' package.json | head -1 | sed -E 's/.*"version": *"([^"]+)".*/\1/')
  fi

  if [[ -z "$last_version" ]]; then
    echo "0.1.0"
  else
    IFS='.' read -r major minor patch <<< "$last_version"
    patch=$((patch + 1))
    echo "$major.$minor.$patch"
  fi
}

get_version_from_branch() {
  local branch="$1"
  if [[ -z "$branch" ]]; then
    echo "Uso: get_version_from_branch <nombre_rama>"
    return 1
  fi

  # Extraer contenido de package.json de la rama especificada
  package_json_content=$(git show "$branch":package.json 2>/dev/null)
  if [[ -z "$package_json_content" ]]; then
    echo "No se pudo obtener package.json de la rama '$branch'"
    return 2
  fi

  # Extraer versión usando jq o grep/sed
  if command -v jq >/dev/null 2>&1; then
    version=$(echo "$package_json_content" | jq -r '.version' 2>/dev/null)
  else
    version=$(echo "$package_json_content" | grep '"version"' | head -1 | sed -E 's/.*"version": *"([^"]+)".*/\1/')
  fi

  if [[ -z "$version" || "$version" == "null" ]]; then
    echo "No se encontró versión válida en package.json de la rama '$branch'"
    return 3
  fi

  echo "$version"
  return 0
}

  echo "Cambiando a la rama master..."
  git checkout master
  echo "Hacemos git pull desde master"
  git pull

actualVersion=$(get_version_from_branch origin/hot-fix)
version=$(increment_version)
date=$(date +%F)
new_entry="### [$version] - $date"$'\n\n'"- Merges ${actualVersion} hot-fix"

# Verificar que el CHANGELOG exista
if [[ ! -f "$CHANGELOG" ]]; then
  echo "No existe el archivo $CHANGELOG" >&2
  exit 1
fi

# Verificar que la cabecera esté presente; si no, salir con error (no hacemos backup ni añadimos al final)
if ! grep -q '^##[[:space:]]*Non-Prod Environment' "$CHANGELOG"; then
  echo "No se encontró la cabecera '## Non-Prod Environment' en $CHANGELOG. Abortando." >&2
  exit 1
fi

# Insertar new_entry justo debajo de la primera ocurrencia de la cabecera,
# dejando una línea en blanco adicional entre la cabecera y la nueva entrada.
tmpfile=$(mktemp)
awk -v new_entry="$new_entry" '
  BEGIN { inserted = 0 }
  /^##[[:space:]]*Non-Prod Environment/ && !inserted {
    print              # imprime la cabecera
    print ""           # imprime una línea en blanco adicional
    print new_entry    # inserta la nueva entrada justo después de la línea en blanco
    inserted = 1
    next
  }
  { print }
' "$CHANGELOG" > "$tmpfile" && mv "$tmpfile" "$CHANGELOG"

echo "Agregado al changelog la versión $version con la entrada:"
printf '%s\n' "$new_entry"

echo "Se añade el changelog a staging"
git add "$CHANGELOG"

if git commit -m "readme: changelog update"; then
    echo "[INFO] Commit creado con mensaje: 'readme: changelog update'."
  else
    echo "[ERROR] Falló el git commit. Revisa la configuración de git o los hooks."
  fi


  echo "Generamos versión en master"  # obtener fecha en formato dd/MM
  fecha="$(date +'%d/%m')"
  echo "$fecha"

  # ejecutar npm version patch con mensaje que incluye la fecha y capturar la salida
  npm_output="$(npm version patch -m "Version %s - $fecha")"
  echo "$npm_output"

  # pusheamos con follow-tags
  push_follow="$(git push origin --follow-tags)"
  echo "$push_follow"

   # ir a la rama maintenance
  echo "Cambiando a la rama maintenance..."
  git checkout maintenance
  git pull
  echo "Hacemos git pull desde maintenance"
  echo "Iniciando merge (sin commit) con master..."
  git merge --no-commit --no-ff master 
  echo "[INFO] Descartando IMAGE del merge (restaurándolo al estado antes del merge)..."
  git restore --source=HEAD --staged --worktree -- IMAGE
  echo "[INFO] Forzando preferencia por master en el resto de archivos conflictivos..."
  git checkout --theirs -- .
  git add -A
  echo "[INFO] Creando commit de merge..."
  git commit -m "Merge master into maintenance"
  echo "Subiendo cambios..."
  git push
  echo "[OK] Proceso completado."


   # ir a la rama develop
  echo "Cambiando a la rama develop..."
  git checkout develop
  git pull
  echo "Hacemos git pull desde develop"
  echo "Iniciando merge (sin commit) con develop..."
  git merge --no-commit --no-ff master 
  echo "[INFO] Descartando IMAGE del merge (restaurándolo al estado antes del merge)..."
  git restore --source=HEAD --staged --worktree -- IMAGE
  echo "[INFO] Forzando preferencia por master en el resto de archivos conflictivos..."
  git checkout --theirs -- .
  git add -A
  echo "[INFO] Creando commit de merge..."
  git commit -m "Merge master into develop"
  echo "Subiendo cambios..."
  git push
  echo "[OK] Proceso completado."
