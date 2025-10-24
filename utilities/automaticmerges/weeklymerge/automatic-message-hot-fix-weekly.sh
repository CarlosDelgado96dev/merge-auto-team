#!/usr/bin/env bash
set -euo pipefail

MSG="${1:-automatic merge from hot-fix weekly}"

# Comprobar repo
GIT_DIR=$(git rev-parse --git-dir 2>/dev/null) || { echo "No es un repo git"; exit 1; }

CHANGELOG="./CHANGELOG.md"

# Extraer sección a partir del encabezado "## Prod Environment" hasta el final
# Si no se encuentra, fallback a todo el CHANGELOG
prod_line=$(grep -n -m1 -E '^##\s*Prod Environment' "$CHANGELOG" 2>/dev/null | cut -d: -f1 || true)
if [[ -n "$prod_line" ]]; then
  search_section=$(tail -n +"$prod_line" "$CHANGELOG")
else
  search_section=$(cat "$CHANGELOG")
fi

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

  package_json_content=$(git show "$branch":package.json 2>/dev/null)
  if [[ -z "$package_json_content" ]]; then
    echo "No se pudo obtener package.json de la rama '$branch'"
    return 2
  fi

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

echo "Cambiando de rama a hot-fix"
git checkout hot-fix
echo "Haciendo pull desde hot-fix"
git pull

merge_commits=$(git log hot-fix --first-parent --since="1 week ago" --merges --pretty=format:"%H")
merge_entries=()
has_new_merges=false

# Procesar commits merge con CHAPQA
for commit_hash in $merge_commits; do
  merge_msg=$(git log -1 --pretty=%B $commit_hash)
  if echo "$merge_msg" | grep -q "CHAPQA"; then
    chapqa_code=$(echo "$merge_msg" | grep -oE "CHAPQA-[0-9]+")
    if [[ -z "$chapqa_code" ]]; then
      echo "[WARN] Commit $commit_hash contiene 'CHAPQA' pero no tiene código CHAPQA válido. Se ignora."
      continue
    fi

    branch_name=$(echo "$merge_msg" | grep -oP "branch '\K[^']+" || echo "rama_desconocida")
    IFS='/' read -r prefix chapqa_code_branch branch_part <<< "$branch_name"
    if [[ -z "$branch_part" ]]; then
      branch_part="$chapqa_code_branch"
      chapqa_code_branch=""
    fi

    formatted_branch=$(echo "$branch_part" | sed -r 's/([a-z])([A-Z])/\1 \2/g' | sed -r 's/\b(.)/\U\1/g')
    entry="- $formatted_branch ($chapqa_code)"

    # Buscar sólo dentro de la sección Prod del changelog
    if echo "$search_section" | grep -qE '\b'"$chapqa_code"'\b'; then
      echo "[INFO] La entrada con código '$chapqa_code' ya existe en la sección Prod del changelog. Saltando..."
      continue
    else
      echo "[INFO] Nueva entrada detectada: '$entry'. Se añadirá al changelog."
    fi

    merge_entries+=("$entry")
    has_new_merges=true
  else
    echo "[DEBUG] Commit $commit_hash no contiene 'CHAPQA', se ignora."
  fi
done

# Obtener rama actual
current_branch=$(git rev-parse --abbrev-ref HEAD)

# Obtener commits no merge de la rama actual en la última semana
remote_commits=$(git log origin/hot-fix --first-parent --since="2 days ago" --no-merges --pretty=format:"%H" --grep='Version [0-9]\+\.[0-9]\+\.[0-9]\+ - [0-9]\{2\}/[0-9]\{2\}' --grep="readme" --grep="Merge branch" --invert-grep)

for commit_hash in $remote_commits; do
  commit_msg=$(git log -1 --pretty=%B "$commit_hash")
  commit_msg_first_line=$(echo "$commit_msg" | head -1 | sed 's/^- *//')
  # Buscar sólo dentro de la sección Prod del changelog
  if echo "$search_section" | grep -qF "$commit_msg_first_line"; then
    echo "[INFO] El commit $commit_hash ya está en la sección Prod del changelog. No se añade."
  else
    echo "[INFO] Añadiendo commit $commit_hash al changelog."
    merge_entries+=("- $commit_msg_first_line")
    has_new_merges=true
  fi
done

if $has_new_merges ; then
  version=$(increment_version)
  date=$(date +%F)
  new_entry="### [$version] - $date"$'\n\n'"$(printf '%s\n' "${merge_entries[@]}")"

  tmpfile=$(mktemp)

  # Si existe el encabezado "## Prod Environment", insertar después de él
  if grep -q -E '^##\s*Prod Environment' "$CHANGELOG"; then
    awk -v new_entry="$new_entry" '
      $0 == "## Prod Environment" {
        print
        print ""
        print new_entry
        next
      }
      { print }
    ' "$CHANGELOG" > "$tmpfile" && mv "$tmpfile" "$CHANGELOG"
  else
    # Si no existe el encabezado Prod, se crea al inicio con la nueva entrada
    {
      printf "%s\n\n" "## Prod Environment"
      printf "%s\n\n" "$new_entry"
      cat "$CHANGELOG"
    } > "$tmpfile" && mv "$tmpfile" "$CHANGELOG"
  fi

  echo "Agregado al changelog la versión $version con las siguientes entradas:"
  printf '%s\n' "${merge_entries[@]}"

  # Comprobar si realmente hay cambios en el archivo y crear commit
  if git diff --quiet -- "$CHANGELOG"; then
    echo "[INFO] No hay cambios reales en $CHANGELOG para commitear."
    exit 0  # Finaliza el script si no hay cambios
  else
    git add "$CHANGELOG"
  fi
else
  echo "No hay merges nuevos para añadir al changelog."
  exit 0
fi

# Stagea todos los cambios (como git add .)
git add -A

# Usamos HEAD como MERGE_HEAD para no introducir un SHA inválido
HEAD_SHA=$(git rev-parse HEAD)

# Escribimos MERGE_HEAD y MERGE_MSG para simular un merge en curso
printf "%s\n" "$HEAD_SHA" > "$GIT_DIR/MERGE_HEAD"
printf "%s\n" "$MSG" > "$GIT_DIR/MERGE_MSG"

echo "Simulado 'merge in progress'. Mensaje escrito en $GIT_DIR/MERGE_MSG"
echo "Ahora abre/actualiza Visual Studio Source Control para ver el pre-commit."
