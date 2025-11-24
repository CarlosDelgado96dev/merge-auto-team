#!/bin/bash
set -euo pipefail

user="${USERNAME:-${USER:-}}"
if [ -z "$user" ]; then
  if command -v cmd.exe >/dev/null 2>&1; then
    user="$(cmd.exe /c 'echo %USERNAME%' | tr -d '\r')"
  elif command -v powershell.exe >/dev/null 2>&1; then
    user="$(powershell.exe -NoProfile -Command '$env:USERNAME' | tr -d '\r')"
  fi
fi


if [[ -d "/c/Users/$user/Downloads" ]]; then
  LOG_DIR="/c/Users/$user/Downloads"
elif [[ -d "/mnt/c/Users/$user/Downloads" ]]; then
  LOG_DIR="/mnt/c/Users/$user/Downloads"
else
  LOG_DIR="C:\\Users\\$user\\Downloads"  
fi

candidates=()

if [[ -d "$LOG_DIR" && ( "$LOG_DIR" == /* ) ]]; then
  
  if command -v find >/dev/null 2>&1 && command -v sort >/dev/null 2>&1; then
    mapfile -t candidates < <(find "$LOG_DIR" -maxdepth 1 -type f -printf '%T@ %p\0' \
      | sort -z -nr \
      | cut -z -f2- -d' ' \
      | tr '\0' '\n' \
      | head -n 4)
  else
   
    mapfile -t candidates < <(ls -1t "$LOG_DIR" 2>/dev/null | head -n 20 | sed "s#^#$LOG_DIR/#")
  fi
else
 
  if command -v powershell.exe >/dev/null 2>&1; then
    mapfile -t candidates < <(powershell.exe -NoProfile -Command \
      "Get-ChildItem -Path 'C:\\Users\\$user\\Downloads' -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 4 -ExpandProperty FullName" \
      | tr -d '\r')
  else
    echo "No se pudo acceder a la carpeta Downloads ni encontrar herramientas para listar archivos." >&2
    exit 1
  fi
fi

# Si PowerShell devolvió rutas con backslashes, convertir antes de basename
found=""
for f in "${candidates[@]}"; do
  # eliminar líneas vacías por si acaso
  [[ -z "$f" ]] && continue
  # convertir backslashes a slashes para que basename funcione bien
  f_slash="${f//\\//}"
  name="$(basename "$f_slash")"
  if [[ $name =~ ^#[0-9]{2,4}\.txt$ ]]; then
    found="$f"
    break
  fi
done

if [ -n "$found" ]; then
  echo "elemento encontrado $found"
else
  echo "No se encontró ningún archivo con la nomenclatura esperada entre los 10 más recientes en $LOG_DIR" >&2
  exit 1
fi


# Extraer nombre
filename="${found##*/}"
echo "Nombre detectado: $filename"

# Comprobar si hay terminal para preguntar (opcional pero recomendable)
if [[ ! -t 0 ]]; then
  echo "No hay terminal disponible para confirmar. Abortando." >&2
  exit 1
fi

# Preguntar al usuario (Enter = no)
read -r -p "¿Es correcto el nombre de archivo '$filename'? [y/N]: " respuesta
# Por defecto a "n" si se pulsa Enter
respuesta="${respuesta:-n}"
# Normalizar a minúsculas y evaluar
case "${respuesta,,}" in
  y|yes)
    echo "Confirmado. Continuando..."
    ;;
  *)
    echo "No confirmado. Finalizando script." >&2
    exit 1
    ;;
esac




echo "Usuario: $user"
# Define el nombre del archivo de log
#LOG_FILE="#1528.txt"

# Extrae el bloque de fallos y lo guarda en un archivo nuevo llamado fallos.txt
awk '/Failures/,/Executed/ {print}' "$found"
