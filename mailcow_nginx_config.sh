#!/bin/bash

# Script para configurar Nginx como Reverse Proxy para Mailcow + Sitio Web
# Solución: Un solo Nginx maneja todo el tráfico

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}   Configurar Nginx + Mailcow (Reverse Proxy)${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""

if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Ejecuta como root: sudo bash $0${NC}"
    exit 1
fi

MAILCOW_DIR="/opt/mailcow-dockerized"
SITE_DOMAIN="otorrinonet.com"
MAIL_DOMAIN="mail.otorrinonet.com"

echo -e "${YELLOW}CONCEPTO:${NC}"
echo "Nginx (puerto 80/443) actúa como intermediario:"
echo "  - $SITE_DOMAIN → Tu sitio web"
echo "  - $MAIL_DOMAIN → Mailcow UI"
echo "  - Puertos de correo (25,587,993) → Directamente a Mailcow"
echo ""

# PASO 1: Verificar Mailcow
echo "=== PASO 1: Verificar instalación de Mailcow ==="
echo ""

if [ ! -d "$MAILCOW_DIR" ]; then
    echo -e "${RED}✗ Mailcow no encontrado en $MAILCOW_DIR${NC}"
    echo "Instala Mailcow primero: https://mailcow.github.io/mailcow-dockerized-docs/"
    exit 1
fi

cd "$MAILCOW_DIR"
echo -e "${GREEN}✓ Mailcow encontrado${NC}"
echo ""

# PASO 2: Configurar Mailcow para usar Nginx externo
echo "=== PASO 2: Configurar Mailcow ==="
echo ""

# Verificar si mailcow.conf existe
if [ ! -f mailcow.conf ]; then
    echo -e "${RED}✗ mailcow.conf no encontrado${NC}"
    exit 1
fi

# Backup de mailcow.conf
cp mailcow.conf mailcow.conf.backup.$(date +%Y%m%d_%H%M%S)
echo -e "${GREEN}✓ Backup creado${NC}"

# Configurar HTTP_PORT y HTTPS_PORT
echo "Configurando puertos para Mailcow..."

# Mailcow debe usar puertos internos diferentes (no 80/443)
# Nginx será el que use 80/443 externamente

# Actualizar o agregar configuraciones
sed -i 's/^HTTP_PORT=.*/HTTP_PORT=8080/' mailcow.conf || echo "HTTP_PORT=8080" >> mailcow.conf
sed -i 's/^HTTPS_PORT=.*/HTTPS_PORT=8443/' mailcow.conf || echo "HTTPS_PORT=8443" >> mailcow.conf
sed -i 's/^HTTP_BIND=.*/HTTP_BIND=127.0.0.1/' mailcow.conf || echo "HTTP_BIND=127.0.0.1" >> mailcow.conf
sed -i 's/^HTTPS_BIND=.*/HTTPS_BIND=127.0.0.1/' mailcow.conf || echo "HTTPS_BIND=127.0.0.1" >> mailcow.conf

echo -e "${GREEN}✓ Mailcow configurado para usar puertos internos:${NC}"
echo "  HTTP_PORT=8080 (solo localhost)"
echo "  HTTPS_PORT=8443 (solo localhost)"
echo ""

# PASO 3: Crear configuración de Nginx para el sitio principal
echo "=== PASO 3: Configurar sitio web principal ==="
echo ""

cat > /etc/nginx/sites-available/$SITE_DOMAIN << 'SITECONF'
server {
    listen 80;
    listen [::]:80;
    
    server_name otorrinonet.com www.otorrinonet.com;
    
    root /var/www/otorrinonet.com;
    index index.html index.htm index.php;
    
    access_log /var/log/nginx/otorrinonet.com.access.log;
    error_log /var/log/nginx/otorrinonet.com.error.log;
    
    # Redirigir a HTTPS (después de configurar SSL)
    # return 301 https://$server_name$request_uri;
    
    location / {
        try_files $uri $uri/ =404;
    }
    
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php8.3-fpm.sock;
    }
    
    location ~ /\.ht {
        deny all;
    }
}

# SSL config (después de certbot)
# server {
#     listen 443 ssl http2;
#     listen [::]:443 ssl http2;
#     
#     server_name otorrinonet.com www.otorrinonet.com;
#     
#     ssl_certificate /etc/letsencrypt/live/otorrinonet.com/fullchain.pem;
#     ssl_certificate_key /etc/letsencrypt/live/otorrinonet.com/privkey.pem;
#     
#     root /var/www/otorrinonet.com;
#     index index.html index.htm index.php;
#     
#     location / {
#         try_files $uri $uri/ =404;
#     }
#     
#     location ~ \.php$ {
#         include snippets/fastcgi-php.conf;
#         fastcgi_pass unix:/var/run/php/php8.3-fpm.sock;
#     }
# }
SITECONF

echo -e "${GREEN}✓ Configuración del sitio creada${NC}"
echo ""

# PASO 4: Crear configuración de Nginx para Mailcow
echo "=== PASO 4: Configurar Mailcow Reverse Proxy ==="
echo ""

cat > /etc/nginx/sites-available/$MAIL_DOMAIN << 'MAILCONF'
server {
    listen 80;
    listen [::]:80;
    
    server_name mail.otorrinonet.com autodiscover.otorrinonet.com autoconfig.otorrinonet.com;
    
    # Logs
    access_log /var/log/nginx/mail.otorrinonet.com.access.log;
    error_log /var/log/nginx/mail.otorrinonet.com.error.log;
    
    # Redirigir todo a HTTPS (después de SSL)
    # return 301 https://$server_name$request_uri;
    
    # Temporalmente hacer proxy a Mailcow HTTP
    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        client_max_body_size 50M;
    }
}

# SSL config para Mailcow (después de certbot)
# server {
#     listen 443 ssl http2;
#     listen [::]:443 ssl http2;
#     
#     server_name mail.otorrinonet.com autodiscover.otorrinonet.com autoconfig.otorrinonet.com;
#     
#     ssl_certificate /etc/letsencrypt/live/mail.otorrinonet.com/fullchain.pem;
#     ssl_certificate_key /etc/letsencrypt/live/mail.otorrinonet.com/privkey.pem;
#     
#     access_log /var/log/nginx/mail.otorrinonet.com.access.log;
#     error_log /var/log/nginx/mail.otorrinonet.com.error.log;
#     
#     location / {
#         proxy_pass https://127.0.0.1:8443;
#         proxy_set_header Host $host;
#         proxy_set_header X-Real-IP $remote_addr;
#         proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
#         proxy_set_header X-Forwarded-Proto $scheme;
#         client_max_body_size 50M;
#         
#         # WebSocket support
#         proxy_http_version 1.1;
#         proxy_set_header Upgrade $http_upgrade;
#         proxy_set_header Connection "upgrade";
#     }
# }
MAILCONF

echo -e "${GREEN}✓ Configuración de Mailcow proxy creada${NC}"
echo ""

# PASO 5: Habilitar sitios
echo "=== PASO 5: Habilitar configuraciones ==="
echo ""

ln -sf /etc/nginx/sites-available/$SITE_DOMAIN /etc/nginx/sites-enabled/
ln -sf /etc/nginx/sites-available/$MAIL_DOMAIN /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

echo -e "${GREEN}✓ Sitios habilitados${NC}"
echo ""

# PASO 6: Verificar configuración
echo "=== PASO 6: Verificar Nginx ==="
echo ""

if nginx -t; then
    echo -e "${GREEN}✓ Configuración correcta${NC}"
else
    echo -e "${RED}✗ Error en configuración${NC}"
    exit 1
fi
echo ""

# PASO 7: Reiniciar Mailcow
echo "=== PASO 7: Reiniciar Mailcow ==="
echo ""

cd "$MAILCOW_DIR"
docker-compose down
sleep 3
docker-compose up -d

echo -e "${GREEN}✓ Mailcow reiniciado con nueva configuración${NC}"
echo ""

# PASO 8: Reiniciar Nginx
echo "=== PASO 8: Reiniciar Nginx ==="
echo ""

systemctl restart nginx
sleep 2

if systemctl is-active --quiet nginx; then
    echo -e "${GREEN}✓ Nginx activo${NC}"
else
    echo -e "${RED}✗ Error al iniciar Nginx${NC}"
    exit 1
fi
echo ""

# PASO 9: Verificar puertos
echo "=== PASO 9: Verificar puertos ==="
echo ""

echo "Puertos escuchando:"
ss -tlnp | grep -E ':80 |:443 |:8080 |:8443 |:25 |:587 |:993 '
echo ""

# PASO 10: Información final
echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}          CONFIGURACIÓN COMPLETADA${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""

echo -e "${GREEN}✓ Arquitectura configurada:${NC}"
echo ""
echo "┌─────────────────────────────────────┐"
echo "│         Internet (puerto 80/443)    │"
echo "└──────────────┬──────────────────────┘"
echo "               │"
echo "               ▼"
echo "┌─────────────────────────────────────┐"
echo "│    Nginx (Reverse Proxy)            │"
echo "│    - Puerto 80/443 público          │"
echo "└──────┬──────────────┬───────────────┘"
echo "       │              │"
echo "       ▼              ▼"
echo "┌──────────────┐  ┌──────────────────┐"
echo "│ Sitio Web    │  │ Mailcow          │"
echo "│ otorrinonet  │  │ mail.otorrinonet │"
echo "│ /var/www/... │  │ :8080/:8443      │"
echo "└──────────────┘  └──────────────────┘"
echo ""

echo "🌐 URLs de acceso:"
echo "   Sitio web: http://otorrinonet.com"
echo "   Mailcow UI: http://mail.otorrinonet.com"
echo "   Webmail: http://mail.otorrinonet.com/SOGo"
echo ""

echo "📧 Puertos de correo (directo a Mailcow):"
echo "   SMTP: 25, 587 (con STARTTLS)"
echo "   IMAP: 143, 993 (SSL)"
echo "   POP3: 110, 995 (SSL)"
echo ""

echo "🔐 IMPORTANTE - Instalar SSL:"
echo "   1. Para el sitio web:"
echo "      certbot --nginx -d otorrinonet.com -d www.otorrinonet.com"
echo ""
echo "   2. Para Mailcow:"
echo "      certbot --nginx -d mail.otorrinonet.com -d autodiscover.otorrinonet.com -d autoconfig.otorrinonet.com"
echo ""
echo "   Después de instalar SSL, descomenta las secciones SSL en:"
echo "   - /etc/nginx/sites-available/$SITE_DOMAIN"
echo "   - /etc/nginx/sites-available/$MAIL_DOMAIN"
echo ""

echo "📊 Verificar funcionamiento:"
echo "   curl http://localhost           # Debe mostrar tu sitio"
echo "   curl http://localhost:8080      # Debe mostrar Mailcow"
echo "   docker-compose ps               # Ver contenedores de Mailcow"
echo ""

echo "⚠️  REGISTROS DNS NECESARIOS:"
echo "   A      otorrinonet.com         → 185.164.111.83"
echo "   A      www.otorrinonet.com     → 185.164.111.83"
echo "   A      mail.otorrinonet.com    → 185.164.111.83"
echo "   A      autodiscover...         → 185.164.111.83"
echo "   A      autoconfig...           → 185.164.111.83"
echo "   MX     otorrinonet.com         → mail.otorrinonet.com (prioridad 10)"
echo ""
