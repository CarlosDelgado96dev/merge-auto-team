#!/usr/bin/env bash
set -euo pipefail

MSG="${1:-automatic merge from master-hot-fix weekly}"

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

# Ejecutar merge pero NO commitear automáticamente (dejar en estado de merge para revisar)
if git merge --no-commit -s recursive -X theirs hot-fix; then
  echo "[INFO] Merge aplicado (sin commit). No hubo conflictos o se resolvieron automáticamente."
  # Restaurar package files desde PRE_MERGE_HEAD y stagearlos para que queden como en master
  for f in "${KEEP_FROM_MASTER[@]}"; do
    if git show "$PRE_MERGE_HEAD":"$f" >/dev/null 2>&1; then
      git checkout "$PRE_MERGE_HEAD" -- "$f" || true
      git add "$f" || true
      echo "[INFO] Restaurado y staged $f desde $PRE_MERGE_HEAD (master)."
    else
      echo "[DEBUG] $f no existe en $PRE_MERGE_HEAD, saltando."
    fi
  done

  # Asegurar/Simular estado de "merge in progress": escribir MERGE_HEAD/MERGE_MSG si no existen
  if [[ -f "$GIT_DIR/MERGE_HEAD" ]]; then
    echo "[INFO] Ya existe un MERGE_HEAD. No se sobrescribe; se actualizará MERGE_MSG con el mensaje predeterminado."
    printf "%s\n" "${MSG}" > "$GIT_DIR/MERGE_MSG"
  else
    if hotfix_sha=$(git rev-parse --verify hot-fix 2>/dev/null); then
      printf "%s\n" "$hotfix_sha" > "$GIT_DIR/MERGE_HEAD"
    else
      # fallback a HEAD si no se puede resolver hot-fix
      printf "%s\n" "$(git rev-parse HEAD)" > "$GIT_DIR/MERGE_HEAD"
    fi
    printf "%s\n" "${MSG}" > "$GIT_DIR/MERGE_MSG"
    echo "[INFO] MERGE_HEAD y MERGE_MSG escritos para simular merge en curso."
  fi

  echo "[NEXT] El merge está en progreso. Revisa cambios con 'git status' y 'git diff'."
  echo "Cuando estés listo, finaliza con: git commit  (o git commit -m \"Merge hot-fix into master\")"
  echo "Si quieres abortar: git merge --abort"

else
  echo "[WARN] El merge terminó con conflictos. Se intentará resolver preferiendo hot-fix excepto package files."

  # Contar archivos en conflicto
  conflict_files_count=$(git ls-files -u | awk '{print $4}' | sort -u | wc -l)
  if [[ "$conflict_files_count" -gt 0 ]]; then
    echo "[INFO] Se han detectado $conflict_files_count archivos en conflicto. Aplicando resolución automática:"
    # Tomar la versión 'theirs' (hot-fix) para los archivos en conflicto
    git checkout --theirs -- . || true

    # Restaurar explícitamente los package files desde PRE_MERGE_HEAD (master)
    for f in "${KEEP_FROM_MASTER[@]}"; do
      if git show "$PRE_MERGE_HEAD":"$f" >/dev/null 2>&1; then
        git checkout "$PRE_MERGE_HEAD" -- "$f" || true
        echo "[INFO] Restaurado $f desde $PRE_MERGE_HEAD (master)."
      else
        echo "[DEBUG] $f no existe en $PRE_MERGE_HEAD, no se restaura."
      fi
    done

    # Marcar como resueltos (stage)
    git add -A

    # Después de stagear, escribir/asegurar MERGE_HEAD y MERGE_MSG (simulación para GUI)
    if [[ -f "$GIT_DIR/MERGE_HEAD" ]]; then
      echo "[INFO] Ya existe un MERGE_HEAD. No se sobrescribe; se actualizará MERGE_MSG con el mensaje predeterminado."
      printf "%s\n" "${MSG}" > "$GIT_DIR/MERGE_MSG"
    else
      if hotfix_sha=$(git rev-parse --verify hot-fix 2>/dev/null); then
        printf "%s\n" "$hotfix_sha" > "$GIT_DIR/MERGE_HEAD"
      else
        printf "%s\n" "$(git rev-parse HEAD)" > "$GIT_DIR/MERGE_HEAD"
      fi
      printf "%s\n" "${MSG}" > "$GIT_DIR/MERGE_MSG"
      echo "[INFO] MERGE_HEAD y MERGE_MSG escritos para simular merge en curso."
    fi

    echo "[NEXT] Conflictos resueltos en automático (theirs) salvo los package*.json que quedaron como master."
    echo "Revisa con 'git status' y 'git diff'. Cuando estés listo, finaliza el merge con 'git commit'."
    echo "Si quieres abortar y volver al estado anterior al merge: git merge --abort"
  else
    echo "[INFO] No se detectaron archivos en conflicto con 'git ls-files -u', pero el merge falló por otra razón."
    echo "Verifica el estado con 'git status' y los mensajes de error de git."
  fi
fi
