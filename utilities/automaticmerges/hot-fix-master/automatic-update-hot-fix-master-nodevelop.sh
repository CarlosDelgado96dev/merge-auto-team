#!/usr/bin/env bash
set -euo pipefail

GIT_DIR=$(git rev-parse --git-dir 2>/dev/null) || { echo "No es un repo git"; exit 1; }

CHANGELOG="./CHANGELOG.md"

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

  # obtener fecha en formato dd/MM
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
echo "[INFO] Guardando la versión ORIGINAL de IMAGE..."

if [[ -f IMAGE ]]; then
   cp IMAGE .IMAGE_BACKUP
   IMAGE_EXISTS=1
else
   IMAGE_EXISTS=0
fi
echo "Iniciando merge con master..."
if git merge --no-ff -s recursive -X theirs master -m "Merge master into maintenance"; then
   echo "[INFO] Merge completado automáticamente."
else
   echo "[WARN] Merge terminó en conflicto. Resolviendo con 'theirs'..."
   conflict_files_count=$(git ls-files -u | awk '{print $4}' | sort -u | wc -l)
   if [[ "$conflict_files_count" -gt 0 ]]; then
       echo "[INFO] Conflictivos detectados ($conflict_files_count). Forzando 'theirs'..."
       git checkout --theirs -- .
       git add -A
       git commit -m "Merge master into maintenance (conflictos resueltos)"
   else
       echo "[ERROR] Merge falló sin conflictos. Abortando..."
       git merge --abort || true
       exit 1
   fi
fi
echo "[INFO] Restaurando el estado ORIGINAL de IMAGE si existía antes del merge..."
if [[ "$IMAGE_EXISTS" -eq 1 ]]; then
   cp .IMAGE_BACKUP IMAGE
   git add IMAGE
fi
# Limpiar temporal SOLO si se creó
#[[ -f .IMAGE_BACKUP ]] && rm -f .IMAGE_BACKUP
echo "[INFO] Enmendando el commit de merge..."
git commit --amend --no-edit
echo "Subiendo cambios..."
git push




