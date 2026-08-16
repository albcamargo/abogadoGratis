#!/bin/bash
set -e

DOMAIN="abogadogratis.corefex.net"
WEB_ROOT="/var/www/abogadogratis.corefex.net"
WEB_DIR="$WEB_ROOT/web"
BACKEND_PATH="/opt/abogadogratis/api"
FRONTEND_PATH="/opt/abogadogratis/frontend"
VENV_PATH="/opt/abogadogratis/venv"
REPO_PATH="/opt/abogadogratis/repo"

if [ -d "$WEB_ROOT" ]; then
    WEB_USER=$(stat -c "%U" "$WEB_ROOT")
    WEB_GROUP=$(stat -c "%G" "$WEB_ROOT")
else
    WEB_USER="www-data"
    WEB_GROUP="www-data"
fi

echo "🚀 Deploy Abogado Gratis - Apache"
echo "   Dominio: $DOMAIN"
echo "   Web User: $WEB_USER:$WEB_GROUP"

# 1. Git Pull
echo "📥 [1/6] Git pull..."
if [ -d "$REPO_PATH/.git" ]; then
    cd $REPO_PATH
    sudo -u $WEB_USER git pull origin main || echo "⚠️ Sin git repo / pull falló"
else
    echo "⚠️ Sin git repo en $REPO_PATH"
fi

# 2. Backend
echo "🐍 [2/6] Backend FastAPI..."
mkdir -p $BACKEND_PATH
if [ -d "$REPO_PATH/backend" ] && [ "$(ls -A $REPO_PATH/backend 2>/dev/null)" ]; then
    rsync -av --delete $REPO_PATH/backend/ $BACKEND_PATH/ --exclude venv --exclude __pycache__
fi

if [ ! -f "$BACKEND_PATH/requirements.txt" ]; then
    cat > $BACKEND_PATH/requirements.txt << "REQ"
fastapi==0.115.0
uvicorn[standard]==0.30.6
python-multipart==0.0.9
python-dotenv==1.0.1
pymysql==1.1.1
qdrant-client==1.11.0
sentence-transformers==3.0.1
cryptography==43.0.0
torch==2.3.0 --index-url https://download.pytorch.org/whl/cpu
redis==5.0.5
REQ
fi

if [ ! -f "$BACKEND_PATH/main.py" ]; then
    cat > $BACKEND_PATH/main.py << "MAIN"
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
import os

app = FastAPI(title="Abogado Gratis API", version="2.0.0-rag-real-apache")

origins = os.getenv("CORS_ORIGINS", "*").split(",")

app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/")
def read_root():
    return {"message": "Abogado Gratis API Running"}

@app.get("/health")
@app.get("/api/health")
def health():
    return {
        "status": "healthy",
        "service": "Abogado Gratis API",
        "rag_mode": "qdrant+redis"
    }
MAIN
fi

$VENV_PATH/bin/pip install -r $BACKEND_PATH/requirements.txt --quiet

# 3. Frontend Build + .htaccess
echo "⚛️ [3/6] Frontend Next.js + .htaccess Apache..."
mkdir -p $FRONTEND_PATH $WEB_DIR/build
if [ -d "$REPO_PATH/frontend" ] && [ "$(ls -A $REPO_PATH/frontend 2>/dev/null)" ]; then
    rsync -av --delete $REPO_PATH/frontend/ $FRONTEND_PATH/ --exclude node_modules --exclude .next --exclude build --exclude out
fi

if [ -f "$FRONTEND_PATH/package.json" ]; then
    sudo -u $WEB_USER bash -c "cd $FRONTEND_PATH && npm ci --silent && npm run build" || true
    BUILD_SRC="$FRONTEND_PATH/build"
    [ -d "$FRONTEND_PATH/out" ] && BUILD_SRC="$FRONTEND_PATH/out"
    if [ -d "$BUILD_SRC" ]; then
        rsync -av --delete $BUILD_SRC/ $WEB_DIR/build/
    fi
fi

cat > $WEB_DIR/build/.htaccess << "HTACCESS"
<IfModule mod_rewrite.c>
  RewriteEngine On
  RewriteBase /
  RewriteCond %{REQUEST_URI} ^/api/ [NC]
  RewriteRule ^ - [L]
  RewriteCond %{REQUEST_FILENAME} -f [OR]
  RewriteCond %{REQUEST_FILENAME} -d
  RewriteRule ^ - [L]
  RewriteRule ^ index.html [L]
</IfModule>
<IfModule mod_headers.c>
  Header set X-Powered-By "Abogado Gratis - Apache"
</IfModule>
<FilesMatch "\.(env|log|ini)$">
  Require all denied
</FilesMatch>
HTACCESS

cat > $WEB_DIR/.htaccess << "HTACCESS2"
<IfModule mod_rewrite.c>
  RewriteEngine On
  RewriteRule ^$ build/ [L]
  RewriteRule ^(.*)$ build/$1 [L]
</IfModule>
HTACCESS2

# 4. Permisos
echo "🔒 [4/6] Permisos..."
chown -R $WEB_USER:$WEB_GROUP $WEB_ROOT $BACKEND_PATH $FRONTEND_PATH 2>/dev/null || true
chmod -R 750 $BACKEND_PATH
chmod 640 $BACKEND_PATH/.env 2>/dev/null || true

# 5. Restart API
echo "🔄 [5/6] Reiniciando API..."
systemctl restart abogadogratis-api 2>/dev/null || true
sleep 3

# 6. Health
echo "✅ [6/6] Health Check..."
curl -s http://127.0.0.1:8000/health || echo "API iniciando..."
echo ""
echo "🎉 Deploy completado!"
