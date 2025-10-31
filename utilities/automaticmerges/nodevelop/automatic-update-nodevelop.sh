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


# If: si versionMaster <= versionMaintenance, mostrar fecha y ejecutar npm
if version_le "$versionMaster" "$versionMaintenance"; then
  echo "Version Master ($versionMaster) es menor o igual que Version Maintenance ($versionMaintenance)"

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
 echo "Uniendo la rama maintenance a master con merge --no-ff y estrategia 'theirs' para conflictos..."
# Intento de merge preferiendo los cambios de maintenance en los hunks en conflicto
if git merge --no-ff -s recursive -X theirs maintenance -m "Merge maintenance into master "; then
  echo "[INFO] Merge completado automáticamente (se han preferido los cambios de maintenance en los hunks en conflicto)."
else
  echo "[WARN] El merge terminó en conflicto o falló. Se intentará resolver forzando las versiones de maintenance en los archivos en conflicto."

  # Comprobar si existen archivos en conflicto
  conflict_files_count=$(git ls-files -u | awk '{print $4}' | sort -u | wc -l)
  if [[ "$conflict_files_count" -gt 0 ]]; then
    echo "[INFO] Se han detectado $conflict_files_count archivos en conflicto. Forzando la versión de maintenance..."
    # Tomar la versión 'theirs' (la rama que se está integrando: maintenance)
    git checkout --theirs -- .

    # Detectar archivos rastreados que coincidan
mapfile -t image_files < <(git ls-files | grep -E '(^Dockerfile$|\.tar$)')

if (( ${#image_files[@]} )); then
  echo "[INFO] Se detectaron ${#image_files[@]} archivos Docker. Eliminándolos del merge..."
  # Quitar del índice (dejarán de estar rastreados en el commit de merge)
  git rm --cached --ignore-unmatch -- "${image_files[@]}"
  # Eliminar del working tree localmente
  rm -f -- "${image_files[@]}"
  # Opcional: añadir reglas locales a .gitignore para evitar que se vuelvan a añadir
  # echo -e "Dockerfile\n*.tar" >> .gitignore
  # git add .gitignore
  # NOTA: no añadimos aquí un commit extra separado para .gitignore para evitar alterar flujo si no lo deseas
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
  echo "Enviando cambios de master y etiquetas al repositorio remoto..."
  git push

fi