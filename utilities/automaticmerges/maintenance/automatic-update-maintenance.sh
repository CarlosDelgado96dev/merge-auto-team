#!/bin/bash

 if git commit -m "readme: changelog update"; then
    echo "[INFO] Commit creado con mensaje: 'readme: changelog update'."
  else
    echo "[ERROR] Falló el git commit. Revisa la configuración de git o los hooks."
  fi

versionMaster=$(get_version_from_branch "master")


versionMaintenance=$(get_version_from_branch "maintenance")


normalize() { printf '%s' "${1#v}" | tr -d '[:space:]'; }
versionMaster=$(normalize "$versionMaster")
echo "Version master $versionMaster"
versionMaintenance=$(normalize "$versionMaintenance")
echo "Version maintenance $versionMaintenance"


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
  echo "Cambiando a la rama master..."
  git checkout master
  git pull
  echo "Hacemos git pull desde master"
  echo "Iniciando merge (sin commit) con maintenance..."
  git merge --no-commit --no-ff maintenance 
  echo "[INFO] Descartando IMAGE del merge (restaurándolo al estado antes del merge)..."
  git restore --source=HEAD --staged --worktree -- IMAGE
  echo "[INFO] Forzando preferencia por maintenance en el resto de archivos conflictivos..."
  git checkout --theirs -- .
  git add -A
  echo "[INFO] Creando commit de merge..."
  git commit -m "Merge maintenance into master"
  echo "Subiendo cambios..."
  git push
  echo "[OK] Proceso completado."

 # ir a la rama master
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


 