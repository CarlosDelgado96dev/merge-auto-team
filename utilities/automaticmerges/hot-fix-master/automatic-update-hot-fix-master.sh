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
git checkout master
git pull
version=$(increment_version)
date=$(date +%F)
# Construir la entrada con solo un salto entre encabezado y cuerpo, sin salto final
new_entry="### [$version] - $date"$'\n\n'"- Merges ${version} hot-fix"
tmpfile=$(mktemp)
awk -v new_entry="$new_entry" '
 $0 == "## Non-Prod Environment" {
   print new_entry
   next
 }
 { print }
' "$CHANGELOG" > "$tmpfile" && mv "$tmpfile" "$CHANGELOG"
echo "Agregado al changelog la versión $version con la entrada:"
printf '%s\n' "$new_entry"

  # ejecutar npm version patch con mensaje que incluye la fecha y capturar la salida
  npm_output="$(npm version patch -m "Version %s - $date")"
  echo "$npm_output"

  # pusheamos con follow-tags
  push_follow="$(git push origin --follow-tags)"
  echo "$push_follow"

    # ir a la rama master
  echo "Cambiando a la rama maintenance..."
  git checkout maintenance
  git pull
  echo "Hacemos git pull desde maintenance"
 echo "Uniendo la rama maintenance a master con merge --no-ff y estrategia 'theirs' para conflictos..."
# Intento de merge preferiendo los cambios de maintenance en los hunks en conflicto
if git merge --no-ff -s recursive -X theirs master -m "Merge master into maintenance "; then
  echo "[INFO] Merge completado automáticamente (se han preferido los cambios de maintenance en los hunks en conflicto)."
else
  echo "[WARN] El merge terminó en conflicto o falló. Se intentará resolver forzando las versiones de maintenance en los archivos en conflicto."

  # Comprobar si existen archivos en conflicto
  conflict_files_count=$(git ls-files -u | awk '{print $4}' | sort -u | wc -l)
  if [[ "$conflict_files_count" -gt 0 ]]; then
    echo "[INFO] Se han detectado $conflict_files_count archivos en conflicto. Forzando la versión de maintenance..."
    # Tomar la versión 'theirs' (la rama que se está integrando: maintenance)
    git checkout --theirs -- .

    image_files=$(git ls-files | grep -E '(^Dockerfile$|\.tar$)')

    if [[ -n "$image_files" ]]; then
      echo "[INFO] Se detectaron archivos relacionados con IMAGE (Docker). Se aplicará manejo especial."
      # Aquí decides qué hacer, por ejemplo, descartar cambios en esos archivos y mantener versión master
      # O eliminarlos si quieres (descomentar según necesidad)

      # Mantener la versión de master (HEAD) para esos archivos
      git checkout HEAD -- $image_files

      # Alternativamente, para eliminarlos del índice y del working tree, usar:
      # git rm --cached --ignore-unmatch $image_files
      # rm -f $image_files
    fi

    # Añadir los cambios y finalizar el merge
    git add -A
    if git commit -m "Merge maintenance into master "; then
      echo "[INFO] Conflictos resueltos: se ha commiteado tomando las versiones de maintenance."
    else
      echo "[ERROR] Falló el commit tras forzar 'theirs'. Revisa manualmente el repo."
      exit 1
    fi
  else
    echo "[ERROR] No se detectaron archivos en conflicto tras el intento de merge. Se abortará el merge para evitar estado inconsistente."
    git merge --abort || true
    exit 1
  fi
fi

  
  # push de master con tags y merge
  echo "Enviando cambios de maintenance y etiquetas al repositorio remoto..."
  git push

fi

    # ir a la rama master
  echo "Cambiando a la rama develop..."
  git checkout develop
  git pull
  echo "Hacemos git pull desde develop"
 echo "Uniendo la rama maintenance a master con merge --no-ff y estrategia 'theirs' para conflictos..."
# Intento de merge preferiendo los cambios de maintenance en los hunks en conflicto
if git merge --no-ff -s recursive -X theirs master -m "Merge master into develop "; then
  echo "[INFO] Merge completado automáticamente (se han preferido los cambios de maintenance en los hunks en conflicto)."
else
  echo "[WARN] El merge terminó en conflicto o falló. Se intentará resolver forzando las versiones de maintenance en los archivos en conflicto."

  # Comprobar si existen archivos en conflicto
  conflict_files_count=$(git ls-files -u | awk '{print $4}' | sort -u | wc -l)
  if [[ "$conflict_files_count" -gt 0 ]]; then
    echo "[INFO] Se han detectado $conflict_files_count archivos en conflicto. Forzando la versión de maintenance..."
    # Tomar la versión 'theirs' (la rama que se está integrando: develop)
    git checkout --theirs -- .

    image_files=$(git ls-files | grep -E '(^Dockerfile$|\.tar$)')

    if [[ -n "$image_files" ]]; then
      echo "[INFO] Se detectaron archivos relacionados con IMAGE (Docker). Se aplicará manejo especial."
      # Aquí decides qué hacer, por ejemplo, descartar cambios en esos archivos y mantener versión develop
      # O eliminarlos si quieres (descomentar según necesidad)

      # Mantener la versión de master (HEAD) para esos archivos
      git checkout HEAD -- $image_files

      # Alternativamente, para eliminarlos del índice y del working tree, usar:
      # git rm --cached --ignore-unmatch $image_files
      # rm -f $image_files
    fi

    # Añadir los cambios y finalizar el merge
    git add -A
    if git commit -m "Merge maintenance into master "; then
      echo "[INFO] Conflictos resueltos: se ha commiteado tomando las versiones de maintenance."
    else
      echo "[ERROR] Falló el commit tras forzar 'theirs'. Revisa manualmente el repo."
      exit 1
    fi
  else
    echo "[ERROR] No se detectaron archivos en conflicto tras el intento de merge. Se abortará el merge para evitar estado inconsistente."
    git merge --abort || true
    exit 1
  fi
fi

  
  # push de master con tags y merge
  echo "Enviando cambios de develop y etiquetas al repositorio remoto..."
  git push

fi