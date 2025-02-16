#!/bin/bash
set -e

echo "---------------------"
echo "   debian-reset.sh   "
echo "---------------------"
echo
echo "Docs: https://github.com/LuisMitaHL/debian-reset"
echo

# Actualizador
if [[ "$1" == "--update" ]]; then
  GITHUB_URL="https://raw.githubusercontent.com/LuisMitaHL/debian-reset/main/debian-reset.sh"
  echo "Actualizando script..."
  curl -L -o "$0.new" "$GITHUB_URL"
  if [ $? -ne 0 ]; then
    echo "Error al descargar la actualización."
    exit 1
  fi
  mv "$0.new" "$0"
  chmod +x "$0"
  echo "Script actualizado."
  exit 0
fi

# TODO: revisar si se pudo elevar
if [[ $EUID -ne 0 ]]; then
  echo "No tenemos permisos de superusuario. Intentando elevar..."
  exec sudo bash "$0" "$@"
  exit 0
fi

# Check
read -p "¿Está seguro de resetear la configuración? (s/n): " confirm1
[[ "$confirm1" != "s" && "$confirm1" != "S" ]] && { echo "Cancelado."; exit 0; }

echo "Esta operación va a borrar toda la configuración modificada. Si no tiene una copia, hágala ahora."
echo
read -p "Confirmar de nuevo: ¿Está seguro de resetear la configuración? (s/n): " confirm2
[[ "$confirm2" != "s" && "$confirm2" != "S" ]] && { echo "Cancelado."; exit 0; }

# -------------------
# Reseteo total
# -------------------

echo "Reseteando Apache2 y PHP..."
systemctl stop apache2 || true
rm -rf /etc/apache2 /etc/php
apt-get purge -y apache2 libapache2-mod-php* php*
apt-get install -y apache2 libapache2-mod-php

echo "Reseteando Nginx..."
systemctl stop nginx || true
rm -rf /etc/nginx || true
# nginx no quiere detenerse
cp -f /bin/true /usr/sbin/nginx
apt-get purge -y nginx*
apt-get install -y nginx

# BUG: nginx no puede escuchar en tcp/80 ya que Apache está presente
sed -i 's/listen 80;/listen 81;/g' /etc/nginx/sites-available/default

echo "Reseteando MariaDB..."
systemctl stop mariadb || true
rm -rf /etc/mysql || true
apt-get purge -y mariadb-server mariadb-client

echo "Reseteando Bind DNS..."
systemctl stop bind9 || true
rm -rf /etc/bind
apt-get purge -y bind9
apt-get install -y bind9

echo "Reseteando configuración de red..."
rm -Rf /etc/network/interfaces* || true
systemctl disable networking || true
systemctl stop networking || true
systemctl enable NetworkManager
systemctl restart NetworkManager

echo "Reseteando resolv.conf..."
cat > /etc/resolv.conf <<EOF
nameserver 1.1.1.1
nameserver 1.0.0.1
EOF

echo "Reiniciando servicios..."
systemctl restart apache2 || true
systemctl restart nginx || true
systemctl restart bind9 || true

echo "Reset completado. Si la red no funciona, se recomienda reiniciar."
echo "En otro caso, puede usar el sistema con normalidad."

echo "Presione Enter para salir..."
read -r
