#!/bin/bash

# --- CONFIGURACIÓN ---
# Reemplaza con los detalles de tu base de datos de otorrinonet.com
DB_NAME="nombre_de_tu_db"
DB_USER="usuario_de_tu_db"
DB_PASS="contraseña_de_tu_db"
BACKUP_DIR="/var/backups/mysql"

# --- EJECUCIÓN ---

# 1. Crear el directorio de backup si no existe
mkdir -p $BACKUP_DIR

# 2. Definir el nombre del archivo con fecha (ej: otorrinonet_2025-11-13_1400.sql.gz)
TIMESTAMP=$(date +"%Y-%m-%d_%H%M")
FILE_NAME="${DB_NAME}_${TIMESTAMP}.sql.gz"

# 3. Realizar el volcado (dump) de la base de datos y comprimir
echo "Iniciando backup de la base de datos ${DB_NAME}..."

mysqldump -u $DB_USER -p$DB_PASS $DB_NAME | gzip > ${BACKUP_DIR}/${FILE_NAME}

if [ $? -eq 0 ]; then
    echo "✅ Backup de DB completado con éxito: ${BACKUP_DIR}/${FILE_NAME}"
    
    # 4. Opcional: Limitar la cantidad de backups (ej: mantener solo los últimos 7 días)
    find $BACKUP_DIR -type f -name "*.sql.gz" -mtime +7 -delete
    echo "Se han eliminado los backups de DB con más de 7 días."
else
    echo "❌ Error al realizar el backup de la base de datos."
fi
