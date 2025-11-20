#!/bin/bash

# Define el nombre del archivo de log
LOG_FILE="#1528.txt"

# Extrae el bloque de fallos y lo guarda en un archivo nuevo llamado fallos.txt
awk '/Failures/,/Executed/ {print}' "$(dirname "$0")/#1528.txt"
