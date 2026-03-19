#!/bin/bash
# ═══════════════════════════════════════════════════════════════
#  MSAR ALHLWL — Web Server + GitHub Setup Script
#  FOR: Kali Linux (OSBoxes) accessed via SSH / PowerShell
#  Usage: sudo ./setup_webserver.sh https://github.com/Moug-lab/msar-website.git
# ═══════════════════════════════════════════════════════════════

set -e
WEBROOT="/var/www/html/msar"
REPO_URL=""

echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║   MSAR ALHLWL — Web Server + GitHub Setup           ║"
echo "║   Kali Linux Edition                                ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""

# ── Prompt for GitHub repo URL if not passed as argument ─────
if [ -z "$1" ]; then
  read -p "  Enter your GitHub repo URL: " REPO_URL
else
  REPO_URL="$1"
fi

# ── 1. Update package lists only (no full upgrade on Kali) ───
echo ""
echo "[1/7] Updating package lists..."
apt-get update -y -q
echo "      Done"

# ── 2. Install Nginx + Git + Curl ───────────────────────────
echo "[2/7] Installing Nginx, Git, Curl..."
apt-get install -y -q nginx git curl
echo "      Done"

# ── 3. Clone or pull repo from GitHub ───────────────────────
echo "[3/7] Setting up website from GitHub..."
if [ -d "/opt/msar-website/.git" ]; then
  echo "      Repo already exists - pulling latest..."
  cd /opt/msar-website && git pull origin main
else
  echo "      Cloning repo..."
  git clone "$REPO_URL" /opt/msar-website
fi
echo "      Done"

# ── 4. Copy files to Nginx web root ─────────────────────────
echo "[4/7] Copying website files to Nginx web root..."
mkdir -p "$WEBROOT"

cp /opt/msar-website/index.html "$WEBROOT/index.html"

[ -f /opt/msar-website/logo.PNG ] && \
  cp /opt/msar-website/logo.PNG "$WEBROOT/logo.PNG" && \
  echo "      logo.PNG copied" || \
  echo "      logo.PNG not found - skipping"

[ -f /opt/msar-website/architecture.png ] && \
  cp /opt/msar-website/architecture.png "$WEBROOT/architecture.png" && \
  echo "      architecture.png copied" || \
  echo "      architecture.png not found - skipping"

chown -R www-data:www-data "$WEBROOT"
chmod -R 755 "$WEBROOT"
echo "      Permissions set"

# ── 5. Configure Nginx virtual host ─────────────────────────
echo "[5/7] Configuring Nginx..."

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
nginx -t && echo "      Nginx config valid"
systemctl enable nginx
systemctl restart nginx
echo "      Nginx running"

# ── 6. Create msar-update command ───────────────────────────
echo "[6/7] Creating msar-update command..."

cat > /usr/local/bin/msar-update << 'UPDATE_SCRIPT'
#!/bin/bash
echo "======================================="
echo " MSAR ALHLWL - Pulling latest from GitHub"
echo "======================================="
cd /opt/msar-website && git pull origin main
cp index.html /var/www/html/msar/
[ -f logo.PNG ] && cp logo.PNG /var/www/html/msar/
[ -f architecture.png ] && cp architecture.png /var/www/html/msar/
chown -R www-data:www-data /var/www/html/msar/
systemctl reload nginx
echo "Site updated successfully!"
echo "======================================="
UPDATE_SCRIPT

chmod +x /usr/local/bin/msar-update
echo "      msar-update command created"

# ── 7. Install Cloudflare tunnel ────────────────────────────
echo "[7/7] Installing Cloudflare tunnel..."
ARCH=$(dpkg --print-architecture)
CF_URL="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${ARCH}.deb"
echo "      Downloading for arch: $ARCH"
curl -fsSL --output /tmp/cloudflared.deb "$CF_URL" && \
  dpkg -i /tmp/cloudflared.deb && \
  echo "      cloudflared installed" || \
  echo "      cloudflared download failed - install manually later"

ufw allow 80/tcp 2>/dev/null || true

# ── Final summary ────────────────────────────────────────────
VM_IP=$(hostname -I | awk '{print $1}')
echo ""
echo "======================================================"
echo " Setup complete!"
echo ""
echo " Local access (Windows browser):"
echo "     http://$VM_IP/"
echo ""
echo " Update site after GitHub push:"
echo "     sudo msar-update"
echo ""
echo " Make site PUBLIC for whole internet:"
echo "     cloudflared tunnel --url http://localhost:80"
echo "     Copy the https://xxxx.trycloudflare.com URL"
echo ""
echo " Web root : /var/www/html/msar/"
echo " Git repo : /opt/msar-website/"
echo " SSH user : osboxes@$VM_IP"
echo "======================================================"
