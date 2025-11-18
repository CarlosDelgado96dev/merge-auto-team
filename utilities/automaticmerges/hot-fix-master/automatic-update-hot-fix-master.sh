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

# Merge master -> develop (descartar cambios en ficheros 'IMAGE' siempre)
echo "Cambiando a la rama maintenance..."
git checkout maintenance
git pull
echo "Hacemos git pull desde maintenance"
echo "Uniendo la rama master a maintenance con merge --no-commit --no-ff y estrategia 'theirs'..."

# Aplicar merge al índice/working-tree pero NO crear commit automático
if git merge --no-commit --no-ff -s recursive -X theirs master; then
  echo "[INFO] Merge aplicado al índice (sin commit)."
else
  echo "[WARN] Merge aplicado al índice con posibles conflictos (sin commit)."
fi

# Detectar archivos cuyo nombre base sea EXACTAMENTE 'IMAGE' (soporta espacios)
declare -a image_files=()
while IFS= read -r -d '' f; do
  if [[ "$(basename "$f")" == "IMAGE" ]]; then
    image_files+=("$f")
  fi
done < <(git ls-files -z)

if (( ${#image_files[@]} )); then
  echo "[INFO] Se detectaron ${#image_files[@]} archivos llamados 'IMAGE'. Se descartarán los cambios entrantes para estos archivos:"
  for p in "${image_files[@]}"; do
    echo "  - $p"
    # Comprobar si el archivo existía en HEAD (nuestra rama antes del merge)
    if git cat-file -e "HEAD:$p" 2>/dev/null; then
      # Existía: conservar la versión 'ours' (rama destino) y añadirla al índice
      git checkout --ours -- "$p"
      git add -- "$p"
      echo "    -> Conservada la versión 'ours' (se ignoraron los cambios entrantes)."
    else
      # No existía en HEAD: fue añadido por la rama entrante. Excluirlo del índice para que NO vaya en el commit.
      git rm --cached --ignore-unmatch -- "$p"
      # NOTA: NO borramos del working tree; el archivo permanecerá localmente como no rastreado.
      echo "    -> Archivo introducido por la rama entrante. Excluido del índice (no se incluirá en el commit)."
    fi
  done
else
  echo "[INFO] No se detectaron archivos llamados 'IMAGE'."
fi

# Si hay conflict files no resueltos y quieres forzar 'theirs' en otros, puedes:
# if git ls-files -u | grep -q .; then
#   git checkout --theirs -- .
#   git add -A
# fi

# Finalizar el merge con el mismo mensaje de siempre
commit_msg="Merge master into maintenance "
git add -A
if git commit -m "$commit_msg"; then
  echo "[INFO] Commit de merge creado con mensaje: '$commit_msg'."
else
  echo "[ERROR] Falló el commit de merge. Revisa el estado del repo:"
  git status --porcelain
  exit 1
fi

# Push si procede
echo "Enviando cambios de maintenance y etiquetas al repositorio remoto..."
git push




# Merge master -> develop (descartar cambios en ficheros 'IMAGE' siempre)
echo "Cambiando a la rama develop..."
git checkout develop
git pull
echo "Hacemos git pull desde develop"
echo "Uniendo la rama master a develop con merge --no-commit --no-ff y estrategia 'theirs'..."

# Aplicar merge al índice/working-tree pero NO crear commit automático
if git merge --no-commit --no-ff -s recursive -X theirs master; then
  echo "[INFO] Merge aplicado al índice (sin commit)."
else
  echo "[WARN] Merge aplicado al índice con posibles conflictos (sin commit)."
fi

# Detectar archivos cuyo nombre base sea EXACTAMENTE 'IMAGE' (soporta espacios)
declare -a image_files=()
while IFS= read -r -d '' f; do
  if [[ "$(basename "$f")" == "IMAGE" ]]; then
    image_files+=("$f")
  fi
done < <(git ls-files -z)

if (( ${#image_files[@]} )); then
  echo "[INFO] Se detectaron ${#image_files[@]} archivos llamados 'IMAGE'. Se descartarán los cambios entrantes para estos archivos:"
  for p in "${image_files[@]}"; do
    echo "  - $p"
    # Comprobar si el archivo existía en HEAD (nuestra rama antes del merge)
    if git cat-file -e "HEAD:$p" 2>/dev/null; then
      # Existía: conservar la versión 'ours' (rama destino) y añadirla al índice
      git checkout --ours -- "$p"
      git add -- "$p"
      echo "    -> Conservada la versión 'ours' (se ignoraron los cambios entrantes)."
    else
      # No existía en HEAD: fue añadido por la rama entrante. Excluirlo del índice para que NO vaya en el commit.
      git rm --cached --ignore-unmatch -- "$p"
      # NOTA: NO borramos del working tree; el archivo permanecerá localmente como no rastreado.
      echo "    -> Archivo introducido por la rama entrante. Excluido del índice (no se incluirá en el commit)."
    fi
  done
else
  echo "[INFO] No se detectaron archivos llamados 'IMAGE'."
fi

# Si hay conflict files no resueltos y quieres forzar 'theirs' en otros, puedes:
# if git ls-files -u | grep -q .; then
#   git checkout --theirs -- .
#   git add -A
# fi

# Finalizar el merge con el mismo mensaje de siempre
commit_msg="Merge master into develop "
git add -A
if git commit -m "$commit_msg"; then
  echo "[INFO] Commit de merge creado con mensaje: '$commit_msg'."
else
  echo "[ERROR] Falló el commit de merge. Revisa el estado del repo:"
  git status --porcelain
  exit 1
fi

# Push si procede
echo "Enviando cambios de develop y etiquetas al repositorio remoto..."
git push
