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
remote_commits=$(git log origin/"$current_branch" --first-parent --since="1 hour ago" --no-merges --pretty=format:"%H" --grep="Version" --grep="readme" --invert-grep)

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

if $has_new_merges; then
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
else
  echo "No hay merges nuevos para añadir al changelog."
fi
