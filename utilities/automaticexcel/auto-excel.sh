#!/bin/bash

set -euo pipefail

### DETECCIÓN DEL USUARIO EN WINDOWS/WSL ###

user="${USERNAME:-${USER:-}}"

if [ -z "$user" ]; then

  if command -v cmd.exe >/dev/null 2>&1; then

    user="$(cmd.exe /c 'echo %USERNAME%' | tr -d '\r')"

  elif command -v powershell.exe >/dev/null 2>&1; then

    user="$(powershell.exe -NoProfile -Command '$env:USERNAME' | tr -d '\r')"

  fi

fi

### DETECCIÓN DE LA RUTA A DOWNLOADS ###

if [[ -d "/c/Users/$user/Downloads" ]]; then

  LOG_DIR="/c/Users/$user/Downloads"

elif [[ -d "/mnt/c/Users/$user/Downloads" ]]; then

  LOG_DIR="/mnt/c/Users/$user/Downloads"

else

  LOG_DIR="C:\\Users\\$user\\Downloads"

fi

echo "Usuario detectado: $user"

echo "Carpeta Downloads detectada: $LOG_DIR"

echo

### PEDIR EL NÚMERO DE EJECUCIÓN ###

read -r -p "Introduce el número de ejecución (ej: 2459): " ejecucion
 
if ! [[ "$ejecucion" =~ ^[0-9]+$ ]]; then

  echo "Error: Debes introducir un número." >&2

  exit 1

fi
 
expected="#${ejecucion}.txt"

echo "Buscando archivo: $expected"

echo
 
### CONVERSIÓN DE RUTAS WINDOWS A WSL SI HACE FALTA ###

if [[ "$LOG_DIR" =~ ^C:\\ ]]; then

  # Convertir C:\Users\xx\Downloads → /mnt/c/Users/xx/Downloads

  LOG_DIR="/mnt/${LOG_DIR:0:1,,}${LOG_DIR:2}"

  LOG_DIR="${LOG_DIR//\\//}"

fi
 
### LISTAR LOS ÚLTIMOS 50 ARCHIVOS ###

if command -v find >/dev/null 2>&1 && command -v sort >/dev/null 2>&1; then

  mapfile -t last50 < <(

    find "$LOG_DIR" -maxdepth 1 -type f -printf '%T@ %p\0' |

    sort -z -nr |

    cut -z -f2- -d' ' |

    tr '\0' '\n' |

    head -n 50

  )

else

  # Alternativa por si no existe find (Windows puro)

  mapfile -t last50 < <(

    ls -1t "$LOG_DIR" | head -n 50 | sed "s#^#$LOG_DIR/#"

  )

fi
 
### BUSCAR EL ARCHIVO DENTRO DE LOS ÚLTIMOS 50 ###

found=""
 
for f in "${last50[@]}"; do

  [[ -z "$f" ]] && continue
 
  # Normalizar por si hay backslashes (Windows)

  f_slash="${f//\\//}"

  name="$(basename "$f_slash")"
 
  if [[ "$name" == "$expected" ]]; then

    found="$f_slash"

    break

  fi

done
 
if [[ -n "$found" ]]; then

  echo "Archivo encontrado en los últimos 50 archivos:"

  echo "$found"

  echo

else

  echo "❌ No se encontró '$expected' entre los últimos 50 archivos de $LOG_DIR" >&2

  exit 1

fi
### EXTRAER BLOQUE DE FALLOS ###

echo

echo "Extrayendo fallos del archivo..."

echo
 
awk '/Failures/,/Executed/ {print}' "$found"
 
echo

echo "Proceso completado."

echo "enviando archivo al script de Python"


"C:/Users/cdelgadb/AppData/Local/Programs/Python/Python313/python.exe" ./utilities/automaticexcel/auto-excel.py "$found"
 