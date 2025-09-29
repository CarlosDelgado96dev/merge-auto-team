#!/bin/bash

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

merge_commits=$(git log --since="1 week ago" --merges --pretty=format:"%H")
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

    if grep -q "$chapqa_code" "$CHANGELOG"; then
      echo "[INFO] La entrada con código '$chapqa_code' ya existe en el changelog. Saltando..."
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
remote_commits=$(git log origin/maintenance --first-parent --since="1 day ago" --no-merges --pretty=format:"%H" --grep="Version" --grep="readme" --grep="Merge branch" --invert-grep)

for commit_hash in $remote_commits; do
  commit_msg=$(git log -1 --pretty=%B "$commit_hash")
  commit_msg_first_line=$(echo "$commit_msg" | head -1 | sed 's/^- *//')
  if grep -qF "$commit_msg_first_line" "$CHANGELOG"; then
    echo "[INFO] El commit $commit_hash ya está en el changelog. No se añade."
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
  awk -v new_entry="$new_entry" '
    $0 == "## Non-Prod Environment" {
      print
      print ""
      print new_entry
      next
    }
    { print }
  ' "$CHANGELOG" > "$tmpfile" && mv "$tmpfile" "$CHANGELOG"

  echo "Agregado al changelog la versión $version con las siguientes entradas:"
  printf '%s\n' "${merge_entries[@]}"

  # Comprobar si realmente hay cambios en el archivo y crear commit
 if git diff --quiet -- "$CHANGELOG"; then
  echo "[INFO] No hay cambios reales en $CHANGELOG para commitear."
else
  git add "$CHANGELOG"
  if git commit -m "readme: changelog update"; then
    echo "[INFO] Commit creado con mensaje: 'readme: changelog update'."
  else
    echo "[ERROR] Falló el git commit. Revisa la configuración de git o los hooks."
  fi
fi
else
  echo "No hay merges nuevos para añadir al changelog."
fi

versionMaster=$(get_version_from_branch "master")


versionMaintenance=$(get_version_from_branch "maintenance")


normalize() { printf '%s' "${1#v}" | tr -d '[:space:]'; }
versionMaster=$(normalize "$versionMaster")
echo "Version master $versionMaster"
versionMaintenance=$(normalize "$versionMaintenance")
echo "Version master $versionMaintenance"


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
  
  # hacer merge con la rama maintenance, aquí se puede elegir si hacer fast-forward o --no-ff
  # para mantener un historial claro, uso --no-ff
  echo "Uniendo la rama maintenance a master con merge --no-ff..."
  git merge maintenance
  
  # push de master con tags y merge
  echo "Enviando cambios de master y etiquetas al repositorio remoto..."
  git push

fi

  
