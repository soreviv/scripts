#!/bin/bash

# Script para solucionar Nginx activo pero sin escuchar en puertos 80/443
# Problema detectado: Nginx running pero puertos cerrados

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}   SOLUCIÓN: Nginx sin escuchar en puertos${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""

if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}ERROR: Ejecuta como root: sudo bash $0${NC}"
    exit 1
fi

echo -e "${YELLOW}PROBLEMA DETECTADO:${NC}"
echo "- Nginx está activo pero NO escucha en puertos 80/443"
echo "- Mailcow está instalado pero contenedores inactivos"
echo ""

# PASO 1: Verificar configuración de Nginx
echo "=== PASO 1: Verificar configuración de Nginx ==="
echo ""

echo "Probando configuración de Nginx..."
if nginx -t 2>&1 | tee /tmp/nginx_test.log; then
    echo -e "${GREEN}✓ Configuración de Nginx correcta${NC}"
else
    echo -e "${RED}✗ Error en configuración de Nginx${NC}"
    echo ""
    echo "Errores encontrados:"
    cat /tmp/nginx_test.log
    echo ""
    echo "Revisa los archivos de configuración en:"
    echo "  /etc/nginx/sites-enabled/"
    echo "  /etc/nginx/nginx.conf"
    exit 1
fi
echo ""

# PASO 2: Verificar qué está escuchando realmente
echo "=== PASO 2: Verificar procesos de Nginx ==="
echo ""

ps aux | grep nginx | grep -v grep
echo ""

echo "Archivos de configuración activos:"
ls -la /etc/nginx/sites-enabled/
echo ""

# PASO 3: Verificar nginx.conf
echo "=== PASO 3: Verificar nginx.conf ==="
echo ""

if grep -q "listen.*80" /etc/nginx/sites-enabled/* 2>/dev/null; then
    echo -e "${GREEN}✓ Se encontraron directivas 'listen 80' en configuración${NC}"
    grep -r "listen" /etc/nginx/sites-enabled/ | head -10
else
    echo -e "${RED}✗ NO se encontraron directivas 'listen 80'${NC}"
    echo "Problema: No hay sitios configurados para escuchar en puerto 80"
fi
echo ""

# PASO 4: Verificar conflicto de puertos
echo "=== PASO 4: Verificar si otro proceso usa los puertos ==="
echo ""

echo "Procesos usando puerto 80:"
lsof -i :80 2>/dev/null || echo "Ninguno"

echo ""
echo "Procesos usando puerto 443:"
lsof -i :443 2>/dev/null || echo "Ninguno"
echo ""

# PASO 5: Verificar y crear configuración de sitio
echo "=== PASO 5: Configurar sitio web otorrinonet.com ==="
echo ""

SITE_CONFIG="/etc/nginx/sites-available/otorrinonet.com"
SITE_ENABLED="/etc/nginx/sites-enabled/otorrinonet.com"
WEB_ROOT="/var/www/otorrinonet.com"

if [ ! -f "$SITE_CONFIG" ]; then
    echo "Creando configuración para otorrinonet.com..."
    
    # Crear directorio web
    mkdir -p "$WEB_ROOT"
    
    # Crear configuración de Nginx
    cat > "$SITE_CONFIG" << 'NGINXCONF'
server {
    listen 80;
    listen [::]:80;
    
    server_name otorrinonet.com www.otorrinonet.com;
    
    root /var/www/otorrinonet.com;
    index index.html index.htm index.php;
    
    # Logs
    access_log /var/log/nginx/otorrinonet.com.access.log;
    error_log /var/log/nginx/otorrinonet.com.error.log;
    
    location / {
        try_files $uri $uri/ =404;
    }
    
    # PHP support (si lo necesitas)
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php8.3-fpm.sock;
    }
    
    location ~ /\.ht {
        deny all;
    }
}
NGINXCONF

    # Habilitar sitio
    ln -sf "$SITE_CONFIG" "$SITE_ENABLED"
    
    # Crear página de prueba
    cat > "$WEB_ROOT/index.html" << 'HTML'
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Otorrinonet.com - Sitio Operativo</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            color: white;
        }
        .container {
            text-align: center;
            padding: 40px;
            background: rgba(255,255,255,0.1);
            backdrop-filter: blur(10px);
            border-radius: 20px;
            box-shadow: 0 8px 32px rgba(0,0,0,0.1);
        }
        h1 { font-size: 3em; margin-bottom: 20px; }
        p { font-size: 1.2em; margin-bottom: 10px; }
        .status {
            display: inline-block;
            padding: 10px 20px;
            background: #10b981;
            border-radius: 50px;
            margin-top: 20px;
            font-weight: bold;
        }
        .info {
            margin-top: 30px;
            font-size: 0.9em;
            opacity: 0.8;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>🎉 Otorrinonet.com</h1>
        <p>Tu sitio web está funcionando correctamente</p>
        <div class="status">✓ Servidor Operativo</div>
        <div class="info">
            <p>Servidor: Nginx</p>
            <p>Estado: Activo y funcionando</p>
        </div>
    </div>
</body>
</html>
HTML
    
    # Permisos correctos
    chown -R www-data:www-data "$WEB_ROOT"
    chmod -R 755 "$WEB_ROOT"
    
    echo -e "${GREEN}✓ Sitio configurado en: $SITE_CONFIG${NC}"
    echo -e "${GREEN}✓ Contenido web en: $WEB_ROOT${NC}"
else
    echo "Configuración ya existe en: $SITE_CONFIG"
fi
echo ""

# PASO 6: Deshabilitar sitio default si existe
echo "=== PASO 6: Limpiar configuraciones default ==="
echo ""

if [ -L /etc/nginx/sites-enabled/default ]; then
    echo "Deshabilitando sitio default..."
    rm -f /etc/nginx/sites-enabled/default
    echo -e "${GREEN}✓ Sitio default deshabilitado${NC}"
fi
echo ""

# PASO 7: Verificar y corregir nginx.conf
echo "=== PASO 7: Verificar nginx.conf principal ==="
echo ""

# Asegurar que nginx.conf incluye sites-enabled
if ! grep -q "include /etc/nginx/sites-enabled/\*;" /etc/nginx/nginx.conf; then
    echo -e "${YELLOW}⚠ Falta include de sites-enabled${NC}"
    echo "Debes agregar esta línea en la sección http de /etc/nginx/nginx.conf:"
    echo "    include /etc/nginx/sites-enabled/*;"
else
    echo -e "${GREEN}✓ nginx.conf incluye sites-enabled${NC}"
fi
echo ""

# PASO 8: Reiniciar Nginx
echo "=== PASO 8: Reiniciar Nginx ==="
echo ""

echo "Verificando sintaxis antes de reiniciar..."
if nginx -t; then
    echo ""
    echo "Deteniendo Nginx..."
    systemctl stop nginx
    sleep 2
    
    echo "Iniciando Nginx..."
    systemctl start nginx
    sleep 2
    
    if systemctl is-active --quiet nginx; then
        echo -e "${GREEN}✓ Nginx reiniciado exitosamente${NC}"
    else
        echo -e "${RED}✗ Error al reiniciar Nginx${NC}"
        systemctl status nginx
        exit 1
    fi
else
    echo -e "${RED}✗ Error en configuración, no se reiniciará${NC}"
    exit 1
fi
echo ""

# PASO 9: Verificar puertos después del reinicio
echo "=== PASO 9: Verificar puertos activos ==="
echo ""

sleep 3
echo "Puertos escuchando ahora:"
netstat -tuln | grep -E ':80 |:443 ' || echo -e "${RED}Aún no escuchando...${NC}"
echo ""

echo "Procesos de Nginx:"
ps aux | grep nginx | grep -v grep
echo ""

# PASO 10: Pruebas finales
echo "=== PASO 10: Pruebas de conectividad ==="
echo ""

echo "Prueba local en puerto 80:"
curl -I http://localhost 2>&1 | head -10
echo ""

echo "Prueba al dominio:"
curl -I http://otorrinonet.com 2>&1 | head -10
echo ""

# PASO 11: Configurar Mailcow
echo "=== PASO 11: Iniciar Mailcow ==="
echo ""

if [ -d /opt/mailcow-dockerized ]; then
    echo "Iniciando contenedores de Mailcow..."
    cd /opt/mailcow-dockerized
    
    # Verificar que el archivo docker-compose existe
    if [ -f docker-compose.yml ]; then
        docker-compose up -d
        echo ""
        echo "Estado de Mailcow:"
        docker-compose ps
    else
        echo -e "${YELLOW}⚠ docker-compose.yml no encontrado${NC}"
    fi
else
    echo -e "${YELLOW}⚠ Mailcow no encontrado en /opt/mailcow-dockerized${NC}"
fi
echo ""

# RESUMEN FINAL
echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}   RESUMEN DE ACCIONES${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""

echo "✓ Verificada configuración de Nginx"
echo "✓ Creado/verificado sitio otorrinonet.com"
echo "✓ Nginx reiniciado"
echo "✓ Mailcow iniciado (si está instalado)"
echo ""

echo -e "${YELLOW}VERIFICACIÓN FINAL:${NC}"
echo ""
if netstat -tuln | grep -q ":80 "; then
    echo -e "${GREEN}✓ Puerto 80 ESCUCHANDO${NC}"
else
    echo -e "${RED}✗ Puerto 80 AÚN NO ESCUCHA${NC}"
    echo ""
    echo -e "${YELLOW}DIAGNÓSTICO ADICIONAL NECESARIO:${NC}"
    echo ""
    echo "1. Verifica logs de Nginx:"
    echo "   journalctl -u nginx -n 50"
    echo ""
    echo "2. Verifica que Nginx está bind al puerto:"
    echo "   ss -tlnp | grep :80"
    echo ""
    echo "3. Verifica configuración completa:"
    echo "   nginx -T | grep listen"
    echo ""
fi

if netstat -tuln | grep -q ":443 "; then
    echo -e "${GREEN}✓ Puerto 443 ESCUCHANDO${NC}"
else
    echo -e "${YELLOW}⚠ Puerto 443 no escucha (normal sin SSL)${NC}"
fi
echo ""

echo -e "${BLUE}PRÓXIMOS PASOS:${NC}"
echo "1. Prueba acceder: http://otorrinonet.com"
echo "2. Si funciona, instala SSL: certbot --nginx -d otorrinonet.com -d www.otorrinonet.com"
echo "3. Configura tu contenido web en: /var/www/otorrinonet.com"
echo "4. Mailcow UI: https://mail.otorrinonet.com"
echo ""
echo "Log de esta sesión: /tmp/nginx_fix_$(date +%Y%m%d_%H%M%S).log"
