#!/bin/bash

# --- CONFIGURACIÓN ---
# Ruta donde está tu proyecto Laravel (ej: /var/www/html/otorrinonet.com)
SOURCE_DIR="/var/www/otorrinonet" 
BACKUP_DIR="/var/backups/files"

# --- EJECUCIÓN ---

# 1. Crear el directorio de backup si no existe
mkdir -p $BACKUP_DIR

# 2. Definir el nombre del archivo con fecha (ej: otorrinonet_files_2025-11-13.tar.gz)
DATE=$(date +"%Y-%m-%d")
FILE_NAME="otorrinonet_files_${DATE}.tar.gz"

echo "Iniciando backup de archivos de Laravel desde ${SOURCE_DIR}..."

# 3. Comprimir el directorio, excluyendo el directorio 'vendor' para ahorrar espacio (si es muy grande)
# Nota: Si omites 'vendor', deberás correr 'composer install' al restaurar.
tar -czf ${BACKUP_DIR}/${FILE_NAME} -C $(dirname $SOURCE_DIR) $(basename $SOURCE_DIR) --exclude='vendor'

if [ $? -eq 0 ]; then
    echo "✅ Backup de archivos completado con éxito: ${BACKUP_DIR}/${FILE_NAME}"
    
    # 4. Opcional: Limitar la cantidad de backups (ej: mantener solo los últimos 4 semanales)
    find $BACKUP_DIR -type f -name "*.tar.gz" -mtime +30 -delete
    echo "Se han eliminado los backups de archivos con más de 30 días."
else
    echo "❌ Error al realizar el backup de archivos."
fi
