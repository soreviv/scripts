#!/bin/bash

# --- Configuración ---
NGINX_SERVICE="nginx"
NGINX_CONF_PATH="/etc/nginx/nginx.conf"
NGINX_SITES_ENABLED="/etc/nginx/sites-enabled"
LOG_DIR="/var/log/nginx"
OUTPUT_FILE="nginx_diagnosis_$(date +%Y%m%d_%H%M%S).txt"

# Función para imprimir un encabezado
print_header() {
    echo "=================================================="
    echo ">>> $1"
    echo "=================================================="
}

# --- 1. Información del Sistema ---
print_header "INFORMACIÓN DEL SISTEMA"
echo "Fecha y Hora: $(date)" >> $OUTPUT_FILE
echo "Hostname: $(hostname)" >> $OUTPUT_FILE
echo "Versión del Kernel: $(uname -r)" >> $OUTPUT_FILE
echo "Versión de Ubuntu: $(lsb_release -d | cut -f2)" >> $OUTPUT_FILE
echo "" >> $OUTPUT_FILE

# --- 2. Estado del Servicio Nginx ---
print_header "ESTADO DEL SERVICIO NGINX"
sudo systemctl status $NGINX_SERVICE --no-pager >> $OUTPUT_FILE
echo "" >> $OUTPUT_FILE

# --- 3. Versión de Nginx y Prueba de Configuración ---
print_header "VERSIÓN Y PRUEBA DE CONFIGURACIÓN DE NGINX"
nginx -v 2>&1 | tee -a $OUTPUT_FILE
sudo nginx -t 2>&1 | tee -a $OUTPUT_FILE
echo "" >> $OUTPUT_FILE

# --- 4. Comprobación de Puertos (80 y 443) ---
print_header "ESTADO DE LOS PUERTOS (80/443)"
# Muestra si Nginx está escuchando en los puertos HTTP (80) y HTTPS (443)
sudo ss -tuln | grep -E ':(80|443)' >> $OUTPUT_FILE
echo "" >> $OUTPUT_FILE

# --- 5. Archivos de Configuración ---
print_header "CONFIGURACIÓN PRINCIPAL ($NGINX_CONF_PATH)"
cat $NGINX_CONF_PATH >> $OUTPUT_FILE
echo "" >> $OUTPUT_FILE

print_header "SITIOS HABILITADOS ($NGINX_SITES_ENABLED)"
# Lista todos los archivos de configuración de sitios habilitados y su contenido
for conf_file in $(ls $NGINX_SITES_ENABLED); do
    echo "--- Archivo: $conf_file ---" >> $OUTPUT_FILE
    cat $NGINX_SITES_ENABLED/$conf_file >> $OUTPUT_FILE
    echo "" >> $OUTPUT_FILE
done
echo "" >> $OUTPUT_FILE

# --- 6. Últimas Entradas de los Logs de Nginx ---
print_header "ÚLTIMAS 20 LÍNEAS DE LOGS DE ERROR"
if [ -f $LOG_DIR/error.log ]; then
    sudo tail -n 20 $LOG_DIR/error.log >> $OUTPUT_FILE
else
    echo "Archivo de log de errores no encontrado en $LOG_DIR/error.log" >> $OUTPUT_FILE
fi
echo "" >> $OUTPUT_FILE

print_header "ÚLTIMAS 20 LÍNEAS DE LOGS DE ACCESO"
# Nota: Podría ser necesario ajustar el log de acceso si se usan nombres personalizados,
# pero se usa access.log como default.
if [ -f $LOG_DIR/access.log ]; then
    sudo tail -n 20 $LOG_DIR/access.log >> $OUTPUT_FILE
else
    echo "Archivo de log de acceso no encontrado en $LOG_DIR/access.log" >> $OUTPUT_FILE
fi
echo "" >> $OUTPUT_FILE

# --- 7. Comprobación de Permisos de Archivos ---
print_header "PERMISOS DE ARCHIVOS DE CONFIGURACIÓN CLAVE"
sudo ls -l $NGINX_CONF_PATH >> $OUTPUT_FILE
sudo ls -ld $NGINX_SITES_ENABLED >> $OUTPUT_FILE
echo "" >> $OUTPUT_FILE

echo "Diagnóstico completado. Los resultados se guardaron en: $OUTPUT_FILE"
