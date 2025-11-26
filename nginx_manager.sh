#!/bin/bash

# nginx_manager.sh
# Un script centralizado para diagnosticar, configurar y solucionar problemas de Nginx.

set -e

# --- Colores ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# --- Funciones de Ayuda ---
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

show_help() {
    echo -e "${BLUE}Nginx Manager Script${NC}"
    echo "Uso: $0 <comando> [argumentos]"
    echo ""
    echo "Comandos:"
    echo "  ${YELLOW}diagnose [dominio]${NC} - Diagnóstico completo del servidor."
    echo "  ${YELLOW}setup-site <dominio>${NC} - Configura un nuevo sitio web."
    echo "  ${YELLOW}setup-mailcow <dominio>${NC} - Configura Nginx para Mailcow."
    echo "  ${YELLOW}fix-ports${NC}          - Intenta solucionar problemas de puertos."
}

# --- Funciones de Comandos ---

install_security_snippet() {
    local SNIPPET_SOURCE="snippets/security_headers.conf"
    local SNIPPET_DEST="/etc/nginx/snippets/security_headers.conf"
    if [ ! -f "$SNIPPET_SOURCE" ]; then log_error "Snippet no encontrado en el repo."; exit 1; fi
    if [ ! -f "$SNIPPET_DEST" ]; then
        log_info "Instalando snippet de seguridad..."
        mkdir -p "$(dirname "$SNIPPET_DEST")"
        cp "$SNIPPET_SOURCE" "$SNIPPET_DEST"
        log_info "✓ Snippet instalado."
    fi
}

run_diagnose() {
    local DOMAIN=${1:-"tu_dominio.com"}
    local LOGFILE="/tmp/nginx_diagnostic_$(date +%Y%m%d_%H%M%S).log"

    exec > >(tee -a "$LOGFILE") 2>&1

    echo "================================================"
    echo "   DIAGNÓSTICO COMPLETO DEL SERVIDOR"
    echo "================================================"
    echo ""

    log_info "--- 1. Verificación de Servicios ---"
    systemctl is-active --quiet nginx && log_info "✓ Nginx está activo" || log_error "✗ Nginx está inactivo"
    if systemctl is-active --quiet apache2; then log_warn "⚠ Apache está activo, puede haber conflicto."; fi
    systemctl is-active --quiet docker && log_info "✓ Docker está activo" || log_warn "✗ Docker inactivo (necesario para Mailcow)"
    echo ""

    log_info "--- 2. Verificación de Puertos ---"
    check_port() {
        lsof -i :$1 >/dev/null && log_info "✓ Puerto $1 ($2) está en uso" || log_error "✗ Puerto $1 ($2) está libre"
    }
    check_port 80 "HTTP"
    check_port 443 "HTTPS"
    check_port 25 "SMTP"
    check_port 587 "SMTP"
    check_port 993 "IMAPS"
    echo ""

    log_info "--- 3. Verificación de Firewall ---"
    if command -v ufw &> /dev/null; then
        ufw status | head -n 10
    else
        log_warn "UFW no encontrado. Mostrando primeras 10 reglas de iptables:"
        iptables -L INPUT -n --line-numbers | head -n 10
    fi
    echo ""

    log_info "--- 4. Verificación de DNS para $DOMAIN ---"
    echo "  Registros A: $(dig +short A $DOMAIN)"
    echo "  Registros MX: $(dig +short MX $DOMAIN)"
    echo ""

    log_info "--- 5. Verificación de Configuración Nginx ---"
    if nginx -t; then log_info "✓ La sintaxis de Nginx es correcta."; else log_error "✗ Error en la sintaxis de Nginx."; fi
    echo ""

    log_info "--- 6. Últimos 10 Errores de Nginx ---"
    if [ -f /var/log/nginx/error.log ]; then
        tail -n 10 /var/log/nginx/error.log
    else
        log_warn "No se encontró el log de errores de Nginx."
    fi
    echo ""

    log_info "--- 7. Recursos del Sistema ---"
    df -h / | awk '{print "  Uso de Disco: " $5 " (" $2 ")"}'
    free -h | awk '/Mem:/ {print "  Uso de Memoria: " $3 "/" $2}'
    echo ""

    log_info "Diagnóstico completado. Log completo en: $LOGFILE"
}

run_setup_site() {
    install_security_snippet
    local DOMAIN=$1
    if [ -z "$DOMAIN" ]; then log_error "Se requiere un dominio."; exit 1; fi

    log_info "Configurando sitio para $DOMAIN..."
    local WEB_ROOT="/var/www/$DOMAIN"
    local SITE_AVAILABLE="/etc/nginx/sites-available/$DOMAIN"

    mkdir -p "$WEB_ROOT" && chown -R www-data:www-data "$WEB_ROOT"
    echo "<h1>$DOMAIN</h1>" > "$WEB_ROOT/index.html"

    cat > "$SITE_AVAILABLE" <<-NGINXCONF
server {
    listen 80; server_name $DOMAIN www.$DOMAIN; root $WEB_ROOT;
    index index.html; include snippets/security_headers.conf;
    location / { try_files \$uri \$uri/ =404; }
}
NGINXCONF

    ln -sf "$SITE_AVAILABLE" "/etc/nginx/sites-enabled/"
    if nginx -t; then systemctl restart nginx; log_info "✓ Sitio $DOMAIN creado."; else log_error "Error de configuración Nginx."; fi
}

run_setup_mailcow() {
    install_security_snippet
    local DOMAIN=$1
    if [ -z "$DOMAIN" ]; then log_error "Se requiere un dominio."; exit 1; fi

    local MAIL_DOMAIN="mail.$DOMAIN"
    local MAILCOW_DIR="/opt/mailcow-dockerized"
    if [ ! -d "$MAILCOW_DIR" ]; then log_error "Mailcow no encontrado."; exit 1; fi

    cd "$MAILCOW_DIR"
    sed -i -e 's/^HTTP_PORT=.*/HTTP_PORT=8080/' -e 's/^HTTPS_PORT=.*/HTTPS_PORT=8443/' -e 's/^HTTP_BIND=.*/HTTP_BIND=127.0.0.1/' -e 's/^HTTPS_BIND=.*/HTTPS_BIND=127.0.0.1/' mailcow.conf

    cat > "/etc/nginx/sites-available/$MAIL_DOMAIN" <<-NGINXCONF
server {
    listen 80; server_name $MAIL_DOMAIN autodiscover.$DOMAIN autoconfig.$DOMAIN;
    include snippets/security_headers.conf;
    location / { proxy_pass http://127.0.0.1:8080; proxy_set_header Host \$host; }
}
NGINXCONF

    ln -sf "/etc/nginx/sites-available/$MAIL_DOMAIN" "/etc/nginx/sites-enabled/"
    if nginx -t; then systemctl restart nginx; docker-compose down && docker-compose up -d; log_info "✓ Mailcow configurado."; else log_error "Error de configuración Nginx."; fi
}

run_fix_ports() {
    log_info "Intentando arreglar puertos..."
    if ! nginx -t; then log_error "Configuración Nginx inválida."; exit 1; fi
    systemctl restart nginx
    if netstat -tuln | grep -q ":80 "; then log_info "✓ Nginx escuchando en puerto 80."; else log_error "El problema persiste."; fi
}

# --- Lógica Principal ---
if [ "$EUID" -ne 0 ]; then log_error "Ejecutar como root."; exit 1; fi
COMMAND=$1
if [ -z "$COMMAND" ]; then show_help; exit 0; fi

case "$COMMAND" in
    help) show_help ;;
    diagnose) shift; run_diagnose "$@" ;;
    setup-site) shift; run_setup_site "$@" ;;
    setup-mailcow) shift; run_setup_mailcow "$@" ;;
    fix-ports) shift; run_fix_ports "$@" ;;
    *) log_error "Comando no válido: $COMMAND"; show_help; exit 1 ;;
esac

exit 0
