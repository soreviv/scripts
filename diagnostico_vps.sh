#!/bin/bash

# Script de Diagnóstico para ERR_CONNECTION_REFUSED
# Sitio: otorrinonet.com + Mailcow
# Autor: Diagnóstico VPS
# Fecha: 2025-11-25

echo "================================================"
echo "   DIAGNÓSTICO VPS - ERR_CONNECTION_REFUSED"
echo "================================================"
echo ""

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Variables
DOMAIN="otorrinonet.com"
LOGFILE="/tmp/vps_diagnostic_$(date +%Y%m%d_%H%M%S).log"

# Función para logging
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1" | tee -a "$LOGFILE"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1" | tee -a "$LOGFILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOGFILE"
}

# 1. VERIFICAR SERVICIOS BÁSICOS
echo "=== 1. VERIFICACIÓN DE SERVICIOS ===" | tee -a "$LOGFILE"
echo ""

# Nginx/Apache
log_info "Verificando servidores web..."
if systemctl is-active --quiet nginx; then
    log_info "✓ Nginx está activo"
    systemctl status nginx --no-pager | head -5 | tee -a "$LOGFILE"
elif systemctl is-active --quiet apache2; then
    log_info "✓ Apache está activo"
    systemctl status apache2 --no-pager | head -5 | tee -a "$LOGFILE"
else
    log_error "✗ No hay servidor web activo (Nginx/Apache)"
fi
echo ""

# Docker (para Mailcow)
log_info "Verificando Docker..."
if systemctl is-active --quiet docker; then
    log_info "✓ Docker está activo"
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | tee -a "$LOGFILE"
else
    log_error "✗ Docker no está activo"
fi
echo ""

# 2. VERIFICAR PUERTOS
echo "=== 2. VERIFICACIÓN DE PUERTOS ===" | tee -a "$LOGFILE"
echo ""

check_port() {
    PORT=$1
    SERVICE=$2
    if netstat -tuln | grep -q ":$PORT "; then
        log_info "✓ Puerto $PORT ($SERVICE) está escuchando"
        netstat -tuln | grep ":$PORT " | tee -a "$LOGFILE"
    else
        log_error "✗ Puerto $PORT ($SERVICE) NO está escuchando"
    fi
}

check_port 80 "HTTP"
check_port 443 "HTTPS"
check_port 25 "SMTP"
check_port 587 "SMTP Submission"
check_port 993 "IMAP SSL"
check_port 995 "POP3 SSL"
echo ""

# 3. VERIFICAR FIREWALL
echo "=== 3. VERIFICACIÓN DE FIREWALL ===" | tee -a "$LOGFILE"
echo ""

# UFW
if command -v ufw &> /dev/null; then
    log_info "Estado de UFW:"
    ufw status verbose | tee -a "$LOGFILE"
fi

# iptables
log_info "Reglas de iptables (INPUT):"
iptables -L INPUT -n -v --line-numbers | head -20 | tee -a "$LOGFILE"
echo ""

# 4. VERIFICAR DNS
echo "=== 4. VERIFICACIÓN DNS ===" | tee -a "$LOGFILE"
echo ""

log_info "Resolución DNS para $DOMAIN:"
dig +short $DOMAIN | tee -a "$LOGFILE"
dig +short www.$DOMAIN | tee -a "$LOGFILE"

log_info "Registros MX:"
dig +short MX $DOMAIN | tee -a "$LOGFILE"
echo ""

# 5. VERIFICAR CONFIGURACIONES
echo "=== 5. CONFIGURACIONES ===" | tee -a "$LOGFILE"
echo ""

# Nginx
if [ -f /etc/nginx/sites-enabled/$DOMAIN ]; then
    log_info "Configuración Nginx encontrada:"
    nginx -t 2>&1 | tee -a "$LOGFILE"
    echo "Archivo: /etc/nginx/sites-enabled/$DOMAIN" | tee -a "$LOGFILE"
elif [ -f /etc/nginx/conf.d/$DOMAIN.conf ]; then
    log_info "Configuración Nginx encontrada:"
    nginx -t 2>&1 | tee -a "$LOGFILE"
    echo "Archivo: /etc/nginx/conf.d/$DOMAIN.conf" | tee -a "$LOGFILE"
fi

# Mailcow
if [ -d /opt/mailcow-dockerized ]; then
    log_info "✓ Mailcow instalado en /opt/mailcow-dockerized"
    cd /opt/mailcow-dockerized
    docker-compose ps | tee -a "$LOGFILE"
else
    log_warn "Mailcow no encontrado en /opt/mailcow-dockerized"
fi
echo ""

# 6. VERIFICAR LOGS
echo "=== 6. LOGS RECIENTES ===" | tee -a "$LOGFILE"
echo ""

if [ -f /var/log/nginx/error.log ]; then
    log_info "Últimos errores de Nginx:"
    tail -20 /var/log/nginx/error.log | tee -a "$LOGFILE"
fi

if [ -f /var/log/apache2/error.log ]; then
    log_info "Últimos errores de Apache:"
    tail -20 /var/log/apache2/error.log | tee -a "$LOGFILE"
fi
echo ""

# 7. CONECTIVIDAD EXTERNA
echo "=== 7. PRUEBAS DE CONECTIVIDAD ===" | tee -a "$LOGFILE"
echo ""

log_info "Probando conexión HTTP al puerto 80:"
timeout 5 curl -I http://$DOMAIN 2>&1 | head -5 | tee -a "$LOGFILE"

log_info "Probando conexión HTTPS al puerto 443:"
timeout 5 curl -I https://$DOMAIN 2>&1 | head -5 | tee -a "$LOGFILE"
echo ""

# 8. RECURSOS DEL SISTEMA
echo "=== 8. RECURSOS DEL SISTEMA ===" | tee -a "$LOGFILE"
echo ""

log_info "Uso de disco:"
df -h / | tee -a "$LOGFILE"

log_info "Uso de memoria:"
free -h | tee -a "$LOGFILE"

log_info "Procesos que más consumen:"
ps aux --sort=-%mem | head -10 | tee -a "$LOGFILE"
echo ""

# 9. RESUMEN Y RECOMENDACIONES
echo "================================================" | tee -a "$LOGFILE"
echo "   RESUMEN Y POSIBLES SOLUCIONES" | tee -a "$LOGFILE"
echo "================================================" | tee -a "$LOGFILE"
echo ""

# Análisis automático
ISSUES_FOUND=0

if ! systemctl is-active --quiet nginx && ! systemctl is-active --quiet apache2; then
    log_error "PROBLEMA: Servidor web no activo"
    echo "  SOLUCIÓN: systemctl start nginx" | tee -a "$LOGFILE"
    ((ISSUES_FOUND++))
fi

if ! systemctl is-active --quiet docker; then
    log_error "PROBLEMA: Docker no activo (necesario para Mailcow)"
    echo "  SOLUCIÓN: systemctl start docker" | tee -a "$LOGFILE"
    ((ISSUES_FOUND++))
fi

if ! netstat -tuln | grep -q ":80 "; then
    log_error "PROBLEMA: Puerto 80 no está escuchando"
    echo "  SOLUCIÓN: Revisar configuración del servidor web y firewall" | tee -a "$LOGFILE"
    ((ISSUES_FOUND++))
fi

if command -v ufw &> /dev/null && ufw status | grep -q "Status: active"; then
    if ! ufw status | grep -q "80.*ALLOW"; then
        log_error "PROBLEMA: Puerto 80 bloqueado por UFW"
        echo "  SOLUCIÓN: ufw allow 80/tcp && ufw allow 443/tcp" | tee -a "$LOGFILE"
        ((ISSUES_FOUND++))
    fi
fi

echo ""
echo "================================================" | tee -a "$LOGFILE"
if [ $ISSUES_FOUND -eq 0 ]; then
    log_info "No se detectaron problemas obvios. Revisar log completo."
else
    log_warn "Se detectaron $ISSUES_FOUND problemas potenciales"
fi
echo "================================================" | tee -a "$LOGFILE"
echo ""
log_info "Log completo guardado en: $LOGFILE"
echo ""

# Generar script de soluciones
cat > /tmp/fix_vps.sh << 'EOF'
#!/bin/bash

echo "Script de Soluciones Rápidas"
echo "============================="
echo ""
echo "IMPORTANTE: Revisa cada comando antes de ejecutarlo"
echo ""

# 1. Reiniciar servicios
echo "1. Reiniciar servicios básicos:"
echo "   sudo systemctl restart nginx"
echo "   sudo systemctl restart docker"
echo "   cd /opt/mailcow-dockerized && docker-compose restart"
echo ""

# 2. Verificar y abrir puertos
echo "2. Abrir puertos en firewall:"
echo "   sudo ufw allow 80/tcp"
echo "   sudo ufw allow 443/tcp"
echo "   sudo ufw allow 25/tcp"
echo "   sudo ufw allow 587/tcp"
echo "   sudo ufw allow 993/tcp"
echo ""

# 3. Verificar configuración Nginx
echo "3. Verificar configuración Nginx:"
echo "   sudo nginx -t"
echo "   sudo systemctl reload nginx"
echo ""

# 4. Logs en tiempo real
echo "4. Monitorear logs:"
echo "   sudo tail -f /var/log/nginx/error.log"
echo "   sudo journalctl -u nginx -f"
echo ""

# 5. Reinicio completo
echo "5. Si todo falla, reinicio completo:"
echo "   sudo systemctl restart nginx docker"
echo "   cd /opt/mailcow-dockerized && docker-compose down && docker-compose up -d"
echo ""
EOF

chmod +x /tmp/fix_vps.sh
log_info "Script de soluciones creado en: /tmp/fix_vps.sh"
echo ""

echo "Para ejecutar las soluciones automáticas, ejecuta:"
echo "  cat /tmp/fix_vps.sh"
