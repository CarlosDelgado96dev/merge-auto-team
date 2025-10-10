#!/usr/bin/env bash
set -euo pipefail

MSG="${1:-automatic merge from maintenance}"

# Comprobar repo
GIT_DIR=$(git rev-parse --git-dir 2>/dev/null) || { echo "No es un repo git"; exit 1; }

CHANGELOG="./CHANGELOG.md"


## Cambiamos a la rama master
git checkout master
git pull



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

# Guardar SHA de HEAD (master) antes del merge
PRE_MERGE_HEAD=$(git rev-parse HEAD)

# Archivos que deben permanecer como en master
KEEP_FROM_MASTER=("package.json" "package-lock.json")

if git merge --no-ff -s recursive -X theirs hot-fix -m "Merge hot-fix into master"; then
  echo "[INFO] Merge completado automáticamente (se han preferido los cambios de hot-fix en los hunks en conflicto)."

  # Restaurar package files desde PRE_MERGE_HEAD y enmendar el commit de merge si hubo cambios
  restore_needed=false
  for f in "${KEEP_FROM_MASTER[@]}"; do
    if git show "$PRE_MERGE_HEAD":"$f" >/dev/null 2>&1; then
      git checkout "$PRE_MERGE_HEAD" -- "$f" || true
      restore_needed=true
    else
      echo "[DEBUG] $f no existe en $PRE_MERGE_HEAD, saltando."
    fi
  done

  if $restore_needed; then
    git add "${KEEP_FROM_MASTER[@]}" || true
    # Solo enmendar si hay cambios staged
    if ! git diff --cached --quiet; then
      git commit --amend --no-edit
      echo "[INFO] Restaurados ${KEEP_FROM_MASTER[*]} desde master y enmendado commit de merge."
    else
      echo "[INFO] No hubo cambios en ${KEEP_FROM_MASTER[*]} para enmendar."
    fi
  fi

else
  echo "[WARN] El merge terminó en conflicto o falló. Se intentará resolver forzando las versiones de hot-fix excepto los package files."

  # Comprobar si existen archivos en conflicto
  conflict_files_count=$(git ls-files -u | awk '{print $4}' | sort -u | wc -l)
  if [[ "$conflict_files_count" -gt 0 ]]; then
    echo "[INFO] Se han detectado $conflict_files_count archivos en conflicto. Forzando la versión de hot-fix para la mayoría de archivos..."
    # Tomar la versión 'theirs' (la rama que se está integrando: hot-fix) para todo
    git checkout --theirs -- .

    # Restaurar explícitamente los package files desde HEAD (master), asegurando que queden como en master
    for f in "${KEEP_FROM_MASTER[@]}"; do
      if git show HEAD:"$f" >/dev/null 2>&1; then
        git checkout HEAD -- "$f" || true
        echo "[INFO] Restaurado $f desde master (HEAD)."
      else
        echo "[DEBUG] $f no existe en master (HEAD), no se restaura."
      fi
    done

    # Marcar como resueltos y crear commit de resolución
    git add -A

    # Comentar mensaje de commit de resolución; puedes ajustarlo
    if git diff --cached --quiet; then
      echo "[INFO] No hay cambios staged después de resolver; no se crea commit."
    else
      git commit -m "Resolve merge conflicts: prefer hot-fix except package.json and package-lock.json (kept from master)"
      echo "[INFO] Conflictos resueltos y commit creado."
    fi

    # Comprobar si existe algún archivo de tipo IMAGE (Docker image) y manejarlo según tu lógica
    image_files=$(git ls-files | grep -E '(^Dockerfile$|\.tar$)' || true)
    if [[ -n "$image_files" ]]; then
      echo "[INFO] Se detectaron archivos relacionados con IMAGE (Docker). Aplicando manejo especial..."
      # Mantener la versión de master (HEAD) para esos archivos
      git checkout HEAD -- $image_files || true
      git add $image_files || true
      echo "[INFO] Restauradas versiones master para archivos de imagen: $image_files"
      # Si quieres, puedes incluirlos en el commit de resolución o crear otro commit
    fi

  else
    echo "[INFO] No se detectaron archivos en conflicto por 'git ls-files -u'."
  fi
fi
