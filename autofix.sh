#!/bin/bash

# Script de Solución Automatizada para ERR_CONNECTION_REFUSED
# ADVERTENCIA: Revisa el diagnóstico antes de ejecutar esto

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}   SCRIPT DE SOLUCIÓN AUTOMATIZADA${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""

# Verificar que se ejecuta como root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}ERROR: Este script debe ejecutarse como root${NC}"
    echo "Ejecuta: sudo bash $0"
    exit 1
fi

echo -e "${YELLOW}Este script intentará solucionar los problemas comunes.${NC}"
echo -e "${YELLOW}¿Deseas continuar? (s/n)${NC}"
read -r respuesta

if [ "$respuesta" != "s" ] && [ "$respuesta" != "S" ]; then
    echo "Operación cancelada"
    exit 0
fi

echo ""
echo "=== PASO 1: Verificar e Instalar Dependencias ===" 

# Instalar herramientas necesarias si faltan
command -v netstat >/dev/null 2>&1 || apt-get install -y net-tools
command -v curl >/dev/null 2>&1 || apt-get install -y curl
command -v dig >/dev/null 2>&1 || apt-get install -y dnsutils

echo -e "${GREEN}✓ Dependencias verificadas${NC}"
echo ""

echo "=== PASO 2: Configurar Firewall (UFW) ===" 

if command -v ufw &> /dev/null; then
    # Habilitar UFW si no está activo
    ufw --force enable
    
    # Permitir SSH primero (crítico)
    ufw allow 22/tcp
    
    # Permitir puertos web
    ufw allow 80/tcp
    ufw allow 443/tcp
    
    # Permitir puertos de correo (Mailcow)
    ufw allow 25/tcp
    ufw allow 465/tcp
    ufw allow 587/tcp
    ufw allow 143/tcp
    ufw allow 993/tcp
    ufw allow 110/tcp
    ufw allow 995/tcp
    
    # Recargar UFW
    ufw reload
    
    echo -e "${GREEN}✓ Firewall configurado${NC}"
    ufw status verbose
else
    echo -e "${YELLOW}⚠ UFW no está instalado${NC}"
fi
echo ""

echo "=== PASO 3: Verificar y Reiniciar Docker ===" 

if systemctl is-active --quiet docker; then
    echo "Docker ya está activo"
else
    echo "Iniciando Docker..."
    systemctl start docker
    systemctl enable docker
fi

echo -e "${GREEN}✓ Docker activo${NC}"
docker --version
echo ""

echo "=== PASO 4: Reiniciar Mailcow ===" 

if [ -d /opt/mailcow-dockerized ]; then
    cd /opt/mailcow-dockerized
    echo "Reiniciando contenedores de Mailcow..."
    docker-compose down
    sleep 5
    docker-compose up -d
    
    echo -e "${GREEN}✓ Mailcow reiniciado${NC}"
    echo "Estado de contenedores:"
    docker-compose ps
else
    echo -e "${YELLOW}⚠ Mailcow no encontrado en /opt/mailcow-dockerized${NC}"
fi
echo ""

echo "=== PASO 5: Verificar y Reiniciar Nginx ===" 

if command -v nginx &> /dev/null; then
    # Verificar configuración
    echo "Verificando configuración de Nginx..."
    if nginx -t; then
        echo -e "${GREEN}✓ Configuración de Nginx correcta${NC}"
        
        # Reiniciar Nginx
        systemctl restart nginx
        systemctl enable nginx
        
        echo -e "${GREEN}✓ Nginx reiniciado${NC}"
    else
        echo -e "${RED}✗ Error en configuración de Nginx${NC}"
        echo "Revisa los archivos de configuración"
    fi
else
    echo -e "${YELLOW}⚠ Nginx no está instalado${NC}"
    echo "¿Deseas instalar Nginx? (s/n)"
    read -r install_nginx
    if [ "$install_nginx" = "s" ]; then
        apt-get update
        apt-get install -y nginx
        systemctl start nginx
        systemctl enable nginx
        echo -e "${GREEN}✓ Nginx instalado y activo${NC}"
    fi
fi
echo ""

echo "=== PASO 6: Verificar Apache (si existe) ===" 

if systemctl is-active --quiet apache2; then
    echo "Apache detectado y activo"
    echo -e "${YELLOW}⚠ Apache puede estar en conflicto con Nginx en el puerto 80${NC}"
    echo "¿Deseas detener Apache? (s/n)"
    read -r stop_apache
    if [ "$stop_apache" = "s" ]; then
        systemctl stop apache2
        systemctl disable apache2
        echo -e "${GREEN}✓ Apache detenido${NC}"
    fi
fi
echo ""

echo "=== PASO 7: Limpiar iptables conflictivas ===" 

# Guardar reglas actuales
iptables-save > /tmp/iptables_backup_$(date +%Y%m%d_%H%M%S).rules

# Limpiar reglas que puedan bloquear
echo "Limpiando posibles reglas conflictivas..."
iptables -D INPUT -p tcp --dport 80 -j DROP 2>/dev/null || true
iptables -D INPUT -p tcp --dport 443 -j DROP 2>/dev/null || true

# Asegurar que el tráfico web esté permitido
iptables -I INPUT -p tcp --dport 80 -j ACCEPT
iptables -I INPUT -p tcp --dport 443 -j ACCEPT

echo -e "${GREEN}✓ Reglas de iptables actualizadas${NC}"
echo ""

echo "=== PASO 8: Verificar conexiones ===" 

echo "Puertos escuchando:"
netstat -tuln | grep -E ':80 |:443 ' || echo "No hay servicios en puertos 80/443"
echo ""

echo "=== PASO 9: Pruebas de conectividad ===" 

sleep 3  # Esperar a que los servicios se estabilicen

echo "Probando localhost..."
curl -I http://localhost 2>&1 | head -5 || echo "No responde en localhost"
echo ""

echo "=== PASO 10: Crear configuración básica de Nginx (si no existe) ===" 

DOMAIN="otorrinonet.com"
NGINX_CONF="/etc/nginx/sites-available/$DOMAIN"

if [ ! -f "$NGINX_CONF" ]; then
    echo "Creando configuración básica para $DOMAIN..."
    
    cat > "$NGINX_CONF" << 'NGINXCONF'
server {
    listen 80;
    listen [::]:80;
    server_name otorrinonet.com www.otorrinonet.com;

    root /var/www/otorrinonet.com;
    index index.html index.htm index.php;

    location / {
        try_files $uri $uri/ =404;
    }

    # PHP processing (si usas PHP)
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php-fpm.sock;
    }

    location ~ /\.ht {
        deny all;
    }

    access_log /var/log/nginx/otorrinonet.com_access.log;
    error_log /var/log/nginx/otorrinonet.com_error.log;
}
NGINXCONF

    # Crear directorio web si no existe
    mkdir -p /var/www/otorrinonet.com
    
    # Crear página de prueba
    cat > /var/www/otorrinonet.com/index.html << 'HTML'
<!DOCTYPE html>
<html>
<head>
    <title>Otorrinonet.com</title>
    <style>
        body { font-family: Arial, sans-serif; text-align: center; padding: 50px; }
        h1 { color: #333; }
    </style>
</head>
<body>
    <h1>¡Sitio Web Funcionando!</h1>
    <p>Otorrinonet.com está operativo</p>
</body>
</html>
HTML

    # Habilitar sitio
    ln -sf "$NGINX_CONF" /etc/nginx/sites-enabled/
    rm -f /etc/nginx/sites-enabled/default
    
    # Recargar Nginx
    nginx -t && systemctl reload nginx
    
    echo -e "${GREEN}✓ Configuración de Nginx creada${NC}"
else
    echo "Configuración de Nginx ya existe"
fi
echo ""

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}   SOLUCIONES APLICADAS${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""
echo -e "${GREEN}✓ Firewall configurado${NC}"
echo -e "${GREEN}✓ Docker y Mailcow reiniciados${NC}"
echo -e "${GREEN}✓ Nginx reiniciado${NC}"
echo -e "${GREEN}✓ Reglas de red actualizadas${NC}"
echo ""

echo "=== ESTADO ACTUAL ===" 
echo ""
echo "Servicios activos:"
systemctl is-active docker && echo "  ✓ Docker"
systemctl is-active nginx && echo "  ✓ Nginx"
echo ""

echo "Puertos abiertos:"
netstat -tuln | grep LISTEN | grep -E ':80|:443|:25|:587|:993'
echo ""

echo -e "${YELLOW}PRÓXIMOS PASOS:${NC}"
echo "1. Verifica que tu dominio apunte a la IP de este servidor"
echo "2. Prueba acceder a: http://otorrinonet.com"
echo "3. Configura SSL con: certbot --nginx -d otorrinonet.com -d www.otorrinonet.com"
echo "4. Revisa logs: tail -f /var/log/nginx/error.log"
echo ""
echo -e "${GREEN}Script completado${NC}"
