#!/bin/bash

# --- CONFIGURACIÓN ---
# Reemplaza con el nombre de tu base de datos y el directorio de backups.
DB_NAME="nombre_de_tu_db"
BACKUP_DIR="/var/backups/mysql"

# --- ADVERTENCIA DE SEGURIDAD ---
# Para mejorar la seguridad, este script ya no almacena credenciales de la base de datos.
# Debes crear un archivo de configuración de MySQL en el directorio home del usuario
# que ejecuta este script (normalmente 'root').
#
# 1. Crea el archivo ~/.my.cnf:
#    touch ~/.my.cnf
#
# 2. Añade el siguiente contenido, reemplazando con tus credenciales:
#    [mysqldump]
#    user=usuario_de_tu_db
#    password=contraseña_de_tu_db
#
# 3. Establece permisos seguros para que solo el propietario pueda leer/escribir:
#    chmod 600 ~/.my.cnf
#

# --- EJECUCIÓN ---

# 1. Crear el directorio de backup si no existe
mkdir -p "$BACKUP_DIR"

# 2. Definir el nombre del archivo con fecha
TIMESTAMP=$(date +"%Y-%m-%d_%H%M")
FILE_NAME="${DB_NAME}_${TIMESTAMP}.sql.gz"

# 3. Realizar el volcado (dump) de la base de datos y comprimir
echo "Iniciando backup de la base de datos ${DB_NAME}..."

# mysqldump leerá las credenciales automáticamente desde ~/.my.cnf
mysqldump "$DB_NAME" | gzip > "${BACKUP_DIR}/${FILE_NAME}"

if [ $? -eq 0 ]; then
    echo "✅ Backup de DB completado con éxito: ${BACKUP_DIR}/${FILE_NAME}"
    
    # 4. Limitar la cantidad de backups (mantener solo los últimos 7 días)
    find "$BACKUP_DIR" -type f -name "*.sql.gz" -mtime +7 -delete
    echo "Se han eliminado los backups de DB con más de 7 días."
else
    echo "❌ Error al realizar el backup. Asegúrate de que ~/.my.cnf está configurado correctamente."
fi
