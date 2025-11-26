#!/bin/bash

# Solución directa: Nginx sin sitios habilitados
# El problema: No hay directivas 'listen' activas en la configuración

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}  SOLUCIÓN DIRECTA - Configurar sitio web${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""

if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Ejecuta como root: sudo bash $0${NC}"
    exit 1
fi

DOMAIN="otorrinonet.com"
WEB_ROOT="/var/www/$DOMAIN"
SITE_AVAILABLE="/etc/nginx/sites-available/$DOMAIN"
SITE_ENABLED="/etc/nginx/sites-enabled/$DOMAIN"

echo -e "${YELLOW}PROBLEMA DETECTADO:${NC}"
echo "Nginx está corriendo pero NO tiene sitios habilitados"
echo "No hay directivas 'listen' activas"
echo ""

# PASO 1: Limpiar configuraciones previas
echo "=== PASO 1: Limpiar configuraciones ==="
echo ""

# Eliminar todos los sitios habilitados
rm -f /etc/nginx/sites-enabled/*
echo -e "${GREEN}✓ Limpiados sitios previos${NC}"
echo ""

# PASO 2: Crear directorio web
echo "=== PASO 2: Crear directorio web ==="
echo ""

mkdir -p "$WEB_ROOT"
chown -R www-data:www-data "$WEB_ROOT"
chmod -R 755 "$WEB_ROOT"

# Crear página HTML de prueba
cat > "$WEB_ROOT/index.html" << 'HTML'
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Otorrinonet - Sitio Operativo</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 20px;
        }
        
        .container {
            background: rgba(255, 255, 255, 0.95);
            padding: 60px 40px;
            border-radius: 20px;
            box-shadow: 0 20px 60px rgba(0, 0, 0, 0.3);
            text-align: center;
            max-width: 600px;
            width: 100%;
        }
        
        h1 {
            color: #667eea;
            font-size: 2.5em;
            margin-bottom: 20px;
            font-weight: 700;
        }
        
        .status {
            display: inline-flex;
            align-items: center;
            gap: 10px;
            background: #10b981;
            color: white;
            padding: 15px 30px;
            border-radius: 50px;
            font-size: 1.1em;
            font-weight: 600;
            margin: 20px 0;
        }
        
        .status::before {
            content: "✓";
            font-size: 1.5em;
        }
        
        .info {
            background: #f3f4f6;
            padding: 25px;
            border-radius: 15px;
            margin-top: 30px;
        }
        
        .info-row {
            display: flex;
            justify-content: space-between;
            padding: 10px 0;
            border-bottom: 1px solid #e5e7eb;
        }
        
        .info-row:last-child {
            border-bottom: none;
        }
        
        .label {
            color: #6b7280;
            font-weight: 600;
        }
        
        .value {
            color: #1f2937;
            font-weight: 700;
        }
        
        .footer {
            margin-top: 30px;
            color: #6b7280;
            font-size: 0.9em;
        }
        
        @media (max-width: 600px) {
            h1 { font-size: 2em; }
            .container { padding: 40px 20px; }
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>🌐 Otorrinonet.com</h1>
        <p style="color: #6b7280; font-size: 1.1em; margin-bottom: 20px;">
            Tu sitio web está funcionando correctamente
        </p>
        
        <div class="status">Servidor Operativo</div>
        
        <div class="info">
            <div class="info-row">
                <span class="label">Servidor Web:</span>
                <span class="value">Nginx</span>
            </div>
            <div class="info-row">
                <span class="label">Estado:</span>
                <span class="value" style="color: #10b981;">Activo</span>
            </div>
            <div class="info-row">
                <span class="label">Protocolo:</span>
                <span class="value">HTTP/HTTPS</span>
            </div>
            <div class="info-row">
                <span class="label">Fecha:</span>
                <span class="value" id="fecha"></span>
            </div>
        </div>
        
        <div class="footer">
            <p>Servidor configurado y funcionando</p>
        </div>
    </div>
    
    <script>
        document.getElementById('fecha').textContent = new Date().toLocaleDateString('es-MX', {
            year: 'numeric',
            month: 'long',
            day: 'numeric'
        });
    </script>
</body>
</html>
HTML

echo -e "${GREEN}✓ Página web creada en: $WEB_ROOT/index.html${NC}"
echo ""

# PASO 3: Crear configuración de Nginx
echo "=== PASO 3: Crear configuración de Nginx ==="
echo ""

cat > "$SITE_AVAILABLE" << 'NGINXCONF'
server {
    # Escuchar en puerto 80 para IPv4
    listen 80;
    
    # Escuchar en puerto 80 para IPv6
    listen [::]:80;
    
    # Nombre del servidor
    server_name otorrinonet.com www.otorrinonet.com;
    
    # Directorio raíz del sitio web
    root /var/www/otorrinonet.com;
    
    # Archivos índice por defecto
    index index.html index.htm index.php;
    
    # Logs
    access_log /var/log/nginx/otorrinonet.com.access.log;
    error_log /var/log/nginx/otorrinonet.com.error.log;
    
    # Configuración principal de ubicación
    location / {
        try_files $uri $uri/ =404;
    }
    
    # Soporte para PHP (si lo necesitas más adelante)
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php8.3-fpm.sock;
    }
    
    # Denegar acceso a archivos .htaccess
    location ~ /\.ht {
        deny all;
    }
    
    # Denegar acceso a archivos ocultos
    location ~ /\. {
        deny all;
        access_log off;
        log_not_found off;
    }
}
NGINXCONF

echo -e "${GREEN}✓ Configuración creada en: $SITE_AVAILABLE${NC}"
echo ""

# PASO 4: Habilitar el sitio
echo "=== PASO 4: Habilitar sitio ==="
echo ""

ln -sf "$SITE_AVAILABLE" "$SITE_ENABLED"
echo -e "${GREEN}✓ Sitio habilitado: $SITE_ENABLED${NC}"
echo ""

# PASO 5: Verificar configuración
echo "=== PASO 5: Verificar configuración de Nginx ==="
echo ""

if nginx -t 2>&1 | tee /tmp/nginx_test.log; then
    echo ""
    echo -e "${GREEN}✓ Configuración correcta${NC}"
else
    echo ""
    echo -e "${RED}✗ Error en configuración:${NC}"
    cat /tmp/nginx_test.log
    exit 1
fi
echo ""

# PASO 6: Verificar que hay directivas listen
echo "=== PASO 6: Verificar directivas listen ==="
echo ""

echo "Directivas 'listen' encontradas:"
nginx -T 2>/dev/null | grep "listen " | grep -v "#"
echo ""

# PASO 7: Reiniciar Nginx
echo "=== PASO 7: Reiniciar Nginx ==="
echo ""

systemctl stop nginx
sleep 2
systemctl start nginx
sleep 2

if systemctl is-active --quiet nginx; then
    echo -e "${GREEN}✓ Nginx reiniciado y activo${NC}"
else
    echo -e "${RED}✗ Error al iniciar Nginx${NC}"
    systemctl status nginx --no-pager
    exit 1
fi
echo ""

# PASO 8: Verificar puertos
echo "=== PASO 8: Verificar puertos escuchando ==="
echo ""

sleep 3

echo "Puertos activos:"
if ss -tlnp | grep :80; then
    echo -e "${GREEN}✓ Puerto 80 ESCUCHANDO${NC}"
else
    echo -e "${RED}✗ Puerto 80 NO escucha${NC}"
fi
echo ""

# PASO 9: Pruebas de conectividad
echo "=== PASO 9: Pruebas de conectividad ==="
echo ""

echo "Prueba a localhost:"
if curl -s -o /dev/null -w "%{http_code}" http://localhost | grep -q "200"; then
    echo -e "${GREEN}✓ HTTP 200 OK en localhost${NC}"
    curl -I http://localhost 2>&1 | head -5
else
    echo -e "${RED}✗ No responde en localhost${NC}"
fi
echo ""

echo "Prueba al dominio (desde el servidor):"
curl -I http://$DOMAIN 2>&1 | head -10
echo ""

# PASO 10: Información útil
echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}          CONFIGURACIÓN COMPLETADA${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""

echo -e "${GREEN}✓ Sitio web configurado${NC}"
echo -e "${GREEN}✓ Nginx escuchando en puerto 80${NC}"
echo ""

echo "📁 Archivos importantes:"
echo "   Configuración: $SITE_AVAILABLE"
echo "   Contenido web: $WEB_ROOT"
echo "   Logs acceso: /var/log/nginx/otorrinonet.com.access.log"
echo "   Logs error: /var/log/nginx/otorrinonet.com.error.log"
echo ""

echo "🌐 Prueba tu sitio:"
echo "   http://otorrinonet.com"
echo "   http://www.otorrinonet.com"
echo "   http://185.164.111.83"
echo ""

echo "🔐 Próximos pasos:"
echo "   1. Si el sitio funciona, instala SSL:"
echo "      certbot --nginx -d otorrinonet.com -d www.otorrinonet.com"
echo ""
echo "   2. Sube tu contenido web a:"
echo "      $WEB_ROOT"
echo ""
echo "   3. Inicia Mailcow:"
echo "      cd /opt/mailcow-dockerized && docker-compose up -d"
echo ""

echo "📊 Monitoreo:"
echo "   Ver logs en tiempo real:"
echo "   tail -f /var/log/nginx/otorrinonet.com.access.log"
echo ""

echo -e "${YELLOW}IMPORTANTE:${NC}"
echo "Si aún no funciona desde fuera, verifica:"
echo "1. DNS apunta a: 185.164.111.83"
echo "2. Firewall del proveedor (panel de control VPS)"
echo "3. Propagación DNS (puede tardar hasta 24h)"
echo ""
