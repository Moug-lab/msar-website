#!/bin/bash
# ═══════════════════════════════════════════════════════════════
#  MSAR ALHLWL — Web Server + GitHub Setup Script
#  Run INSIDE Ubuntu VM:
#    chmod +x setup_webserver.sh && sudo ./setup_webserver.sh
# ═══════════════════════════════════════════════════════════════

set -e
WEBROOT="/var/www/html/msar"
REPO_URL=""   # filled by prompt below or pass as arg: sudo ./setup_webserver.sh https://github.com/YOU/msar-website

echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║   MSAR ALHLWL — Web Server + GitHub Setup           ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""

# ── Prompt for GitHub repo URL if not passed ─────────────────
if [ -z "$1" ]; then
  read -p "  Enter your GitHub repo URL (e.g. https://github.com/user/msar-website): " REPO_URL
else
  REPO_URL="$1"
fi

# ── 1. Update system ─────────────────────────────────────────
echo ""
echo "[1/7] Updating system packages..."
apt-get update -y -q
apt-get upgrade -y -q

# ── 2. Install Nginx + Git ───────────────────────────────────
echo "[2/7] Installing Nginx and Git..."
apt-get install -y -q nginx git curl

# ── 3. Clone or pull from GitHub ────────────────────────────
echo "[3/7] Setting up website from GitHub..."
if [ -d "/opt/msar-website/.git" ]; then
  echo "      ↻ Repo exists — pulling latest..."
  cd /opt/msar-website && git pull origin main
else
  echo "      ↓ Cloning repo..."
  git clone "$REPO_URL" /opt/msar-website
fi

# ── 4. Copy files to web root ────────────────────────────────
echo "[4/7] Copying website files to Nginx root..."
mkdir -p "$WEBROOT"
cp /opt/msar-website/index.html "$WEBROOT/index.html"
cp /opt/msar-website/logo.PNG   "$WEBROOT/logo.PNG"  2>/dev/null || true
cp /opt/msar-website/architecture.png "$WEBROOT/architecture.png" 2>/dev/null || true

chown -R www-data:www-data "$WEBROOT"
chmod -R 755 "$WEBROOT"

# ── 5. Configure Nginx ───────────────────────────────────────
echo "[5/7] Configuring Nginx virtual host..."
cat > /etc/nginx/sites-available/msar << 'NGINX_CONF'
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    root /var/www/html/msar;
    index index.html;
    server_name _;

    location / {
        try_files $uri $uri/ =404;
    }

    location ~* \.(png|jpg|jpeg|gif|ico|svg|css|js)$ {
        expires 7d;
        add_header Cache-Control "public, immutable";
    }

    gzip on;
    gzip_types text/html text/css application/javascript;
    add_header X-Frame-Options "SAMEORIGIN";
    add_header X-Content-Type-Options "nosniff";
}
NGINX_CONF

ln -sf /etc/nginx/sites-available/msar /etc/nginx/sites-enabled/msar
rm -f /etc/nginx/sites-enabled/default
nginx -t
systemctl enable nginx
systemctl restart nginx

# ── 6. Create auto-update script ────────────────────────────
echo "[6/7] Creating auto-update script..."
cat > /usr/local/bin/msar-update << 'UPDATE_SCRIPT'
#!/bin/bash
# Run this any time you push to GitHub to update the live site
echo "Pulling latest from GitHub..."
cd /opt/msar-website && git pull origin main
echo "Copying files to web root..."
cp index.html /var/www/html/msar/
cp logo.PNG   /var/www/html/msar/ 2>/dev/null || true
cp architecture.png /var/www/html/msar/ 2>/dev/null || true
chown -R www-data:www-data /var/www/html/msar/
echo "Done! Site updated."
UPDATE_SCRIPT
chmod +x /usr/local/bin/msar-update

# ── 7. Install Cloudflare tunnel ────────────────────────────
echo "[7/7] Installing Cloudflare tunnel (cloudflared)..."
curl -L --output /tmp/cloudflared.deb \
  https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb 2>/dev/null || \
  echo "      ⚠ Could not download cloudflared — install manually (see guide)"
if [ -f /tmp/cloudflared.deb ]; then
  dpkg -i /tmp/cloudflared.deb && echo "      ✔ cloudflared installed"
fi

# ── Done ─────────────────────────────────────────────────────
VM_IP=$(hostname -I | awk '{print $1}')
echo ""
echo "══════════════════════════════════════════════════════"
echo " ✅  Setup complete!"
echo ""
echo " 🌐  Local access (same network):"
echo "     http://$VM_IP/"
echo ""
echo " 🔄  To update site after GitHub push:"
echo "     sudo msar-update"
echo ""
echo " 🌍  For PUBLIC internet access, run:"
echo "     cloudflared tunnel --url http://localhost:80"
echo "     (copy the https://....trycloudflare.com URL)"
echo ""
echo " 📁  Web root: /var/www/html/msar/"
echo " 📦  Repo:     /opt/msar-website/"
echo "══════════════════════════════════════════════════════"
echo ""
