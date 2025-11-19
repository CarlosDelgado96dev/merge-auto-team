#!/bin/bash

 if git commit -m "readme: changelog update"; then
    echo "[INFO] Commit creado con mensaje: 'readme: changelog update'."
  else
    echo "[ERROR] Falló el git commit. Revisa la configuración de git o los hooks."
  fi

versionProd=$(get_version_from_branch "prod")


versionHotfix=$(get_version_from_branch "hot-fix")


normalize() { printf '%s' "${1#v}" | tr -d '[:space:]'; }
versionProd=$(normalize "$versionProd")
echo "Version produccion $versionProd"
versionHotfix=$(normalize "$versionHotfix")
echo "Version hot-fix $versionHotfix"


version_le() {
  local a="$1" b="$2"


  if command -v dpkg >/dev/null 2>&1; then
    dpkg --compare-versions "$a" le "$b"
    return $?
  fi

 
  [ "$a" = "$b" ] && return 0
  if [ "$(printf '%s\n%s\n' "$a" "$b" | sort -V | head -n1)" = "$a" ]; then
    return 0
  else
    return 1
  fi
}

  # ir a la rama hot-fix
  echo "Cambiamos a la rama hot-fix..."
  git checkout hot-fix


  # obtener fecha en formato dd/MM
  fecha="$(date +'%d/%m')"
  echo "$fecha"

  # ejecutar npm version patch con mensaje que incluye la fecha y capturar la salida
  npm_output="$(npm version patch -m "Version %s - $fecha")"
  echo "$npm_output"

  # pusheamos con follow-tags
  push_follow="$(git push origin --follow-tags)"
  echo "$push_follow"

   # ir a la rama master
  echo "Cambiando a la rama produccion..."
  git checkout produccion
  git pull
  echo "Hacemos git pull desde produccion"
  echo "Iniciando merge (sin commit) con hot-fix..."
  git merge --no-commit --no-ff hot-fix 
  echo "[INFO] Descartando IMAGE del merge (restaurándolo al estado antes del merge)..."
  git restore --source=HEAD --staged --worktree -- IMAGE
  echo "[INFO] Forzando preferencia por hot-fix en el resto de archivos conflictivos..."
  git checkout --theirs -- .
  git add -A
  echo "[INFO] Creando commit de merge..."
  git commit -m "Merge hot-fix into produccion"
  echo "Subiendo cambios..."
  git push
  echo "[OK] Proceso completado."
