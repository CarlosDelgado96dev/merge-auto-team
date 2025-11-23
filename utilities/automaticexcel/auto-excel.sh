#!/bin/bash


user="${USERNAME:-$USER}"
if [ -z "$user" ]; then
  if command -v cmd.exe >/dev/null 2>&1; then
    user="$(cmd.exe /c 'echo %USERNAME%' | tr -d '\r')"
  elif command -v powershell.exe >/dev/null 2>&1; then
    user="$(powershell.exe -NoProfile -Command '$env:USERNAME' | tr -d '\r')"
  fi
fi

LOG_FILE1="C:\Users\"$user\Downloads"


echo "Usuario: $user"
# Define el nombre del archivo de log
LOG_FILE="#1528.txt"

# Extrae el bloque de fallos y lo guarda en un archivo nuevo llamado fallos.txt
awk '/Failures/,/Executed/ {print}' "$(dirname "$0")/#1528.txt"
