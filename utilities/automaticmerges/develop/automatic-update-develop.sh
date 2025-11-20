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





semVerType="${1}"

# Informar si el parámetro fue pasado explícitamente o se usó el predeterminado
if [[ "$1" != "patch" && "$1" != "minor" ]]; then
  echo "Parámetro inválido: se requiere 'patch' o 'minor'." >&2
  exit 1
fi

echo "Cambiando a la rama master..."
git checkout master
echo "Hacemos git pull desde master"
git fetch
git pull

masterVersion=$(get_version_from_branch origin/master)



echo "Cambiando a la rama develop..."
git checkout develop
git pull





