#!/bin/bash
# install-prod.sh - Abogado Gratis - Instalación Completa CORREGIDA Network + Bind Check
# Dominio: abogadogratis.corefex.net
# Stack: Ubuntu 24.04 + ISPConfig + Apache 2.4 + MariaDB 10.11 + Docker + Qdrant 1.11.3 + Redis 7.4 + FastAPI RAG Real + Next.js 14 export
# Fix 1: network abogadogratis-network gateway 172.20.0.1 en misma entrada subnet (antes separado causaba "parent subnet invalid Prefix doesn't contain this address")
# Fix 2: check directorios bind /opt/qdrant_storage /opt/redis_data antes de docker compose up (evita Volume Error)
# Sincronizado con: main.py 2.0.0-rag-real-apache, globals.css print premium, deploy.sh 6 pasos Apache, docker-compose.prod.yml corregido
# Uso: sudo ./install-prod.sh [--skip-ispconfig] [--skip-docker]

set -e

DOMAIN=${DOMAIN:-abogadogratis.corefex.net}
REPO_URL=${REPO_URL:-https://github.com/albcamargo/abogadogratis.git}
BRANCH=${BRANCH:-main}
SKIP_ISPCONFIG=${SKIP_ISPCONFIG:-false}
SKIP_DOCKER=${SKIP_DOCKER:-false}

WEB_ROOT="/var/www/$DOMAIN"
WEB_DIR="$WEB_ROOT/web"
BACKEND_PATH="/opt/abogadogratis/api"
FRONTEND_PATH="/opt/abogadogratis/frontend"
VENV_PATH="/opt/abogadogratis/venv"
REPO_PATH="/opt/abogadogratis/repo"
QDRANT_DIR="/opt/qdrant"
STORAGE_DIR="/opt/qdrant_storage"
REDIS_DIR="/opt/redis_data"
BACKUP_DIR="/opt/backups/abogadogratis"
LOG_DIR="/var/log/abogadogratis"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}"
cat << 'BANNER'
╔════════════════════════════════════════════════════════════════╗
║  Abogado Gratis - Install Prod CORREGIDO                       ║
║  Fix Network 172.20.0.1 + Bind Dirs Check                      ║
║  Ubuntu 24.04 + ISPConfig + Apache + Qdrant+Redis+Backup      ║
╚════════════════════════════════════════════════════════════════╝
BANNER
echo -e "${NC}"

if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}❌ Debe ejecutarse como root: sudo ./install-prod.sh${NC}"
  exit 1
fi

for arg in "$@"; do
  case $arg in
    --skip-ispconfig) SKIP_ISPCONFIG=true ;;
    --skip-docker) SKIP_DOCKER=true ;;
    --domain=*) DOMAIN="${arg#*=}" ;;
    --repo=*) REPO_URL="${arg#*=}" ;;
    --branch=*) BRANCH="${arg#*=}" ;;
  esac
done

echo -e "${YELLOW}Config:${NC} DOMAIN=$DOMAIN REPO=$REPO_URL BRANCH=$BRANCH SKIP_ISPCONFIG=$SKIP_ISPCONFIG SKIP_DOCKER=$SKIP_DOCKER"

# [1/12] Sistema base
echo -e "${GREEN}📦 [1/12] Sistema base Ubuntu 24.04 + deps...${NC}"
apt update
apt install -y curl wget git rsync jq unzip htop net-tools python3 python3-venv python3-pip python3-dev build-essential libssl-dev libffi-dev mariadb-client apache2-utils certbot
# FIX nodejs Conflicts: npm - NodeSource nodejs ya incluye npm, no instalar npm separado

echo "🔍 Verificando Node.js..."
if ! command -v node &> /dev/null || ! node --version 2>/dev/null | grep -q "v20\|v21\|v22"; then
  echo "📦 Instalando Node 20 LTS (NodeSource incluye npm, sin paquete npm separado para evitar Conflicts: npm)..."
  apt remove -y npm 2>/dev/null || true
  if [ ! -f "/etc/apt/sources.list.d/nodesource.list" ] && [ ! -f "/etc/apt/sources.list.d/nodesource.sources" ]; then
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
  fi
  apt install -y nodejs
  echo "✅ Node instalado: $(node --version) + npm $(npm --version) (npm incluido)"
else
  echo "✅ Node OK: $(node --version) + npm $(npm --version 2>/dev/null || echo 'incluido')"
fi
echo "Node: $(node --version) NPM: $(npm --version) Python: $(python3 --version)"

# [2/12] Docker
if [ "$SKIP_DOCKER" = "false" ]; then
  echo -e "${GREEN}🐳 [2/12] Docker + Compose...${NC}"
  if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com | sh
    systemctl enable --now docker
  fi
  docker --version
  docker compose version || apt install -y docker-compose-plugin
else
  echo -e "${YELLOW}⏭️ [2/12] Saltando Docker${NC}"
fi

# [3/12] Directorios prod + FIX BIND CHECK
echo -e "${GREEN}📁 [3/12] Directorios prod + check bind (fix Volume Error)...${NC}"
mkdir -p $QDRANT_DIR $STORAGE_DIR $REDIS_DIR $BACKUP_DIR $LOG_DIR
mkdir -p /opt/abogadogratis/api /opt/abogadogratis/frontend /opt/abogadogratis/repo
mkdir -p $WEB_ROOT 2>/dev/null || true
echo "  Creando y validando bind mounts (CRÍTICO para evitar Volume Error)..."
for dir in $STORAGE_DIR $REDIS_DIR $BACKUP_DIR $LOG_DIR; do
  mkdir -p $dir
  ls -ld $dir
done
chown -R 1000:1000 $STORAGE_DIR $REDIS_DIR 2>/dev/null || true
chmod 750 $STORAGE_DIR $REDIS_DIR
chmod 755 $BACKUP_DIR $LOG_DIR
echo "✅ Directorios: $QDRANT_DIR $STORAGE_DIR $REDIS_DIR $BACKUP_DIR $LOG_DIR"

# [4/12] ISPConfig Website
echo -e "${GREEN}🌐 [4/12] ISPConfig Website $DOMAIN...${NC}"
if [ -d "$WEB_ROOT" ]; then
  WEB_USER=$(stat -c '%U' "$WEB_ROOT")
  WEB_GROUP=$(stat -c '%G' "$WEB_ROOT")
  echo "✅ Website ISPConfig existe: $WEB_ROOT user $WEB_USER:$WEB_GROUP"
else
  if [ "$SKIP_ISPCONFIG" = "false" ]; then
    echo -e "${RED}❌ $WEB_ROOT no existe. Crea Website en ISPConfig primero.${NC}"
    echo "  ISPConfig > Sites > Website > Add: Domain $DOMAIN, PHP Disabled, SSL+Let's Encrypt, Apache Directives ProxyPass /api/ http://127.0.0.1:8000/api/"
    exit 1
  else
    echo -e "${YELLOW}⚠️ Saltando ISPConfig check, usando www-data${NC}"
    mkdir -p $WEB_DIR
    WEB_USER="www-data"
    WEB_GROUP="www-data"
  fi
fi
if [ -d "$WEB_ROOT" ]; then
  WEB_USER=$(stat -c '%U' "$WEB_ROOT" 2>/dev/null || echo www-data)
  WEB_GROUP=$(stat -c '%G' "$WEB_ROOT" 2>/dev/null || echo www-data)
else
  WEB_USER="www-data"
  WEB_GROUP="www-data"
fi
echo "WEB_USER: $WEB_USER:$WEB_GROUP"

# [5/12] Repo git
echo -e "${GREEN}📥 [5/12] Repo git $REPO_URL $BRANCH...${NC}"
if [ -d "$REPO_PATH/.git" ]; then
  cd $REPO_PATH
  sudo -u $WEB_USER git fetch origin || true
  sudo -u $WEB_USER git checkout $BRANCH || true
  sudo -u $WEB_USER git pull origin $BRANCH || echo "⚠️ Git pull falló, usando locales"
else
  rm -rf $REPO_PATH
  sudo -u $WEB_USER git clone -b $BRANCH $REPO_URL $REPO_PATH || (echo "⚠️ Clone falló, placeholder" && mkdir -p $REPO_PATH/backend $REPO_PATH/frontend && echo "# placeholder" > $REPO_PATH/README.md)
fi

# [6/12] docker-compose.prod.yml CORREGIDO + configs
echo -e "${GREEN}🐳 [6/12] docker-compose.prod.yml CORREGIDO (fix network gateway) + redis.conf + qdrant_config + backup-cron.sh...${NC}"

cat > $QDRANT_DIR/docker-compose.prod.yml << 'COMPOSE'
services:
  qdrant:
    image: qdrant/qdrant:v1.11.3
    container_name: abogadogratis-qdrant
    restart: unless-stopped
    ports:
      - "127.0.0.1:6333:6333"
      - "127.0.0.1:6334:6334"
    volumes:
      - qdrant_storage:/qdrant/storage
      - ./qdrant_config.yaml:/qdrant/config/production.yaml:ro
      - /var/log/abogadogratis:/var/log/abogadogratis
      - /opt/backups/abogadogratis:/backups
    environment:
      - QDRANT__LOG_LEVEL=INFO
    healthcheck:
      test: ["CMD-SHELL", "bash -c ': > /dev/tcp/127.0.0.1/6333' || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
      start_interval: 5s
    deploy:
      resources:
        limits:
          cpus: '1.5'
          memory: 1.5G
        reservations:
          cpus: '0.5'
          memory: 512M
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
    networks:
      - abogadogratis-network

  redis:
    image: redis:7.4-alpine
    container_name: abogadogratis-redis
    restart: unless-stopped
    ports:
      - "127.0.0.1:6379:6379"
    volumes:
      - redis_data:/data
      - ./redis.conf:/usr/local/etc/redis/redis.conf:ro
    command: ["redis-server", "/usr/local/etc/redis/redis.conf"]
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 20s
      timeout: 5s
      retries: 3
      start_period: 10s
    deploy:
      resources:
        limits:
          cpus: '0.5'
          memory: 256M
        reservations:
          cpus: '0.2'
          memory: 64M
    logging:
      driver: "json-file"
      options:
        max-size: "5m"
        max-file: "3"
    networks:
      - abogadogratis-network

  backup:
    image: alpine:3.20
    container_name: abogadogratis-backup
    restart: unless-stopped
    volumes:
      - qdrant_storage:/qdrant/storage:ro
      - redis_data:/redis/data:ro
      - /opt/backups/abogadogratis:/backups
      - /opt/abogadogratis/api/.env:/app/.env:ro
      - ./backup-cron.sh:/usr/local/bin/backup-cron.sh:ro
      - /var/log/abogadogratis:/var/log/abogadogratis
    environment:
      - BACKUP_DIR=/backups
      - DB_HOST=172.20.0.1
      - QDRANT_HOST=qdrant
      - QDRANT_PORT=6333
      - REDIS_HOST=redis
      - REDIS_PORT=6379
      - RETENTION_DAYS=7
    entrypoint: ["/bin/sh", "-c"]
    command:
      - |
        apk add --no-cache mysql-client curl redis bash
        echo "0 2 * * * /usr/local/bin/backup-cron.sh >> /var/log/abogadogratis/backup-cron.log 2>&1" | crontab -
        crond -f -l 8
    depends_on:
      qdrant:
        condition: service_healthy
      redis:
        condition: service_healthy
    deploy:
      resources:
        limits:
          cpus: '0.3'
          memory: 128M
    logging:
      driver: "json-file"
      options:
        max-size: "5m"
        max-file: "2"
    networks:
      - abogadogratis-network

networks:
  abogadogratis-network:
    name: abogadogratis-network
    driver: bridge
    ipam:
      config:
        - subnet: 172.20.0.0/16
          gateway: 172.20.0.1

volumes:
  qdrant_storage:
    name: abogadogratis-qdrant-storage
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /opt/qdrant_storage
  redis_data:
    name: abogadogratis-redis-data
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /opt/redis_data
COMPOSE

cat > $QDRANT_DIR/qdrant_config.yaml << 'QCONF'
storage:
  storage_path: /qdrant/storage
  snapshots_path: /qdrant/storage/snapshots
  optimizers:
    default_segment_number: 2
    flush_interval_sec: 30
  hnsw_index:
    m: 16
    ef_construct: 100
  performance:
    max_search_threads: 2
    max_optimization_threads: 1
    update_rate: 100
service:
  http_port: 6333
  grpc_port: 6334
  enable_cors: false
  enable_tls: false
cluster:
  enabled: false
log_level: INFO
QCONF

cat > $QDRANT_DIR/redis.conf << 'RCONF'
bind 0.0.0.0
protected-mode yes
port 6379
save 3600 1
save 300 100
save 60 10000
dbfilename dump.rdb
dir /data
maxmemory 200mb
maxmemory-policy allkeys-lru
hz 10
tcp-keepalive 60
timeout 300
loglevel notice
logfile ""
appendonly no
RCONF

cat > $QDRANT_DIR/backup-cron.sh << 'BSCRIPT'
#!/bin/bash
set -e
BACKUP_DIR=${BACKUP_DIR:-/backups}
DATE=$(date +%Y%m%d_%H%M%S)
RETENTION_DAYS=${RETENTION_DAYS:-7}
DB_HOST=${DB_HOST:-172.20.0.1}
QDRANT_HOST=${QDRANT_HOST:-qdrant}
QDRANT_PORT=${QDRANT_PORT:-6333}
REDIS_HOST=${REDIS_HOST:-redis}
mkdir -p $BACKUP_DIR /var/log/abogadogratis
echo "[$DATE] Backup automático prod..."
if [ -f /app/.env ]; then source /app/.env; fi
echo "📦 MariaDB..."
if [ -n "$DB_USER" ] && [ -n "$DB_PASS" ]; then
  mysqldump -h $DB_HOST -u $DB_USER -p$DB_PASS $DB_NAME --single-transaction 2>/dev/null | gzip > $BACKUP_DIR/mariadb_${DATE}.sql.gz && echo "✅ MariaDB" || echo "⚠️ MariaDB falló"
fi
echo "📦 Qdrant snapshots..."
for COL in abogado_gratis_legal; do curl -s -X POST http://$QDRANT_HOST:$QDRANT_PORT/collections/$COL/snapshots -H 'Content-Type: application/json' -d '{}' | grep -q snapshot && echo "✅ Snapshot $COL" || true; cp /qdrant/storage/snapshots/$COL/*.snapshot $BACKUP_DIR/ 2>/dev/null || true; done
tar czf $BACKUP_DIR/qdrant_storage_${DATE}.tar.gz /qdrant/storage --exclude='*.tmp' 2>/dev/null && echo "✅ Qdrant tar" || true
echo "📦 Redis..."
if redis-cli -h $REDIS_HOST -p 6379 ping 2>/dev/null | grep -q PONG; then redis-cli -h $REDIS_HOST -p 6379 --rdb $BACKUP_DIR/redis_dump_${DATE}.rdb 2>/dev/null && echo "✅ Redis" || cp /redis/data/dump.rdb $BACKUP_DIR/redis_dump_${DATE}.rdb 2>/dev/null || true; fi
find $BACKUP_DIR -type f -mtime +$RETENTION_DAYS -delete 2>/dev/null || true
echo "=== BACKUP $DATE COMPLETADO ==="; ls -lh $BACKUP_DIR/*${DATE}* 2>/dev/null | awk '{print $9, $5}' || true
BSCRIPT
chmod +x $QDRANT_DIR/backup-cron.sh

if [ -f "/mnt/data/docker-compose.prod.yml" ]; then cp /mnt/data/docker-compose.prod.yml $QDRANT_DIR/docker-compose.prod.yml; echo "Usado docker-compose.prod.yml de /mnt/data (artefacto vigente corregido)"; fi
echo "✅ docker-compose.prod.yml CORREGIDO + configs listos"
grep -A3 "ipam:" $QDRANT_DIR/docker-compose.prod.yml | head -5

# [7/12] Backend + Frontend + .env
echo -e "${GREEN}🐍 [7/12] Backend FastAPI RAG Real + Frontend + .env...${NC}"
if [ -f "/mnt/data/main.py" ]; then
  cp /mnt/data/main.py $BACKEND_PATH/main.py
  echo "Usado main.py 2.0.0-rag-real-apache de /mnt/data"
elif [ -f "$REPO_PATH/backend/main.py" ]; then
  rsync -av $REPO_PATH/backend/ $BACKEND_PATH/ --exclude venv --exclude __pycache__
fi
if [ -f "/mnt/data/redis_cache.py" ]; then cp /mnt/data/redis_cache.py $BACKEND_PATH/redis_cache.py; fi
if [ ! -d "$FRONTEND_PATH/app" ] && [ -f "/mnt/data/globals.css" ]; then
  mkdir -p $FRONTEND_PATH/app
  cp /mnt/data/globals.css $FRONTEND_PATH/app/globals.css
fi
if [ -d "$REPO_PATH/frontend" ]; then rsync -av --delete $REPO_PATH/frontend/ $FRONTEND_PATH/ --exclude node_modules --exclude .next --exclude build --exclude out || true; fi

if [ ! -f "$BACKEND_PATH/.env" ]; then
  DB_PASS_GEN=$(openssl rand -base64 12 | tr -dc 'a-zA-Z0-9' | head -c 16)
  cat > $BACKEND_PATH/.env << ENV
QDRANT_HOST=127.0.0.1
QDRANT_PORT=6333
DB_HOST=localhost
DB_USER=abogadogratis
DB_PASS=$DB_PASS_GEN
DB_NAME=abogadogratis_db
CORS_ORIGINS=https://$DOMAIN
EMBEDDING_MODEL=sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2
REDIS_HOST=127.0.0.1
REDIS_PORT=6379
REDIS_DB=0
ENV
  chmod 640 $BACKEND_PATH/.env
  echo -e "${YELLOW}⚠️ .env generado pass: $DB_PASS_GEN${NC}"
else
  echo "✅ .env existe"
  chmod 640 $BACKEND_PATH/.env
fi

if [ ! -f "$BACKEND_PATH/requirements.txt" ]; then
  cat > $BACKEND_PATH/requirements.txt << 'REQ'
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

# [8/12] Venv + deps
echo -e "${GREEN}📦 [8/12] Venv + deps...${NC}"
if [ ! -d "$VENV_PATH" ]; then python3 -m venv $VENV_PATH; fi
sudo -u $WEB_USER $VENV_PATH/bin/pip install --upgrade pip --quiet
sudo -u $WEB_USER $VENV_PATH/bin/pip install -r $BACKEND_PATH/requirements.txt --quiet || sudo -u $WEB_USER $VENV_PATH/bin/pip install -r $BACKEND_PATH/requirements.txt
if [ -f "$FRONTEND_PATH/package.json" ]; then sudo -u $WEB_USER bash -c "cd $FRONTEND_PATH && npm ci --silent" || sudo -u $WEB_USER bash -c "cd $FRONTEND_PATH && npm install"; fi

# [9/12] Systemd
echo -e "${GREEN}⚙️ [9/12] Systemd abogadogratis-api.service...${NC}"
cat > /etc/systemd/system/abogadogratis-api.service << SERVICE
[Unit]
Description=Abogado Gratis API - RAG Real Prod
After=network.target docker.service
Wants=docker.service

[Service]
User=$WEB_USER
Group=$WEB_GROUP
WorkingDirectory=$BACKEND_PATH
Environment="PATH=$VENV_PATH/bin"
ExecStart=$VENV_PATH/bin/uvicorn main:app --host 127.0.0.1 --port 8000 --workers 2
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
SERVICE
systemctl daemon-reload
systemctl enable abogadogratis-api.service

# [10/12] Prod up CORREGIDO con fix network + bind check
echo -e "${GREEN}🚀 [10/12] Prod up CORREGIDO Qdrant+Redis+Backup cron (fix network + bind check)...${NC}"
echo "🧹 Limpiando network vieja con error si existe..."
cd $QDRANT_DIR
docker compose -f docker-compose.prod.yml down -v --remove-orphans 2>/dev/null || true
docker network rm abogadogratis-network 2>/dev/null || true

echo "📁 Verificando bind mounts existen (fix Volume Error)..."
for dir in $STORAGE_DIR $REDIS_DIR $BACKUP_DIR $LOG_DIR; do
  mkdir -p $dir
  echo "  $dir -> $(ls -ld $dir | awk '{print $9}')"
done
chown -R 1000:1000 $STORAGE_DIR $REDIS_DIR 2>/dev/null || true
chmod 750 $STORAGE_DIR $REDIS_DIR

echo "🔍 Verificando fix ipam config..."
if grep -A1 "subnet: 172.20.0.0/16" $QDRANT_DIR/docker-compose.prod.yml | grep -q "^\s*- gateway"; then
  echo -e "${RED}❌ Config aún MAL - corrigiendo...${NC}"
  python3 -c "
import pathlib
p=pathlib.Path('$QDRANT_DIR/docker-compose.prod.yml')
t=p.read_text()
t=t.replace('- subnet: 172.20.0.0/16\n        - gateway: 172.20.0.1', '- subnet: 172.20.0.0/16\n          gateway: 172.20.0.1')
p.write_text(t)
"
fi
grep -A3 "ipam:" $QDRANT_DIR/docker-compose.prod.yml

echo "🚀 Docker compose up -d..."
cd $QDRANT_DIR
docker compose -f docker-compose.prod.yml up -d
sleep 15
for i in {1..8}; do
  Q=$(docker inspect --format='{{.State.Health.Status}}' abogadogratis-qdrant 2>/dev/null || echo "starting")
  R=$(docker inspect --format='{{.State.Health.Status}}' abogadogratis-redis 2>/dev/null || echo "starting")
  B=$(docker inspect --format='{{.State.Status}}' abogadogratis-backup 2>/dev/null || echo "starting")
  echo "  Intento $i/8: Qdrant=$Q Redis=$R Backup=$B"
  if [ "$Q" = "healthy" ] && [ "$R" = "healthy" ]; then echo -e "${GREEN}✅ Qdrant y Redis healthy!${NC}"; break; fi
  sleep 5
done
docker ps --filter "name=abogadogratis" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
docker network inspect abogadogratis-network --format '{{json .IPAM.Config}}' 2>/dev/null | jq 2>/dev/null || docker network inspect abogadogratis-network | grep -A5 "172.20" | head -10
curl -s http://127.0.0.1:6333/healthz && echo -e "${GREEN} ✅ Qdrant healthz ok${NC}" || echo -e "${RED} ❌ Qdrant healthz falló${NC}"
redis-cli -h 127.0.0.1 -p 6379 ping 2>/dev/null | grep -q PONG && echo -e "${GREEN} ✅ Redis PONG${NC}" || echo -e "${YELLOW} ⚠️ Redis no responde aún${NC}"

# [11/12] Seed + Start API + Health
echo -e "${GREEN}🌱 [11/12] Seed corpus 20 leyes + Start API + Health...${NC}"
systemctl restart abogadogratis-api
sleep 5
systemctl is-active abogadogratis-api
curl -s http://127.0.0.1:8000/health | head -20 || echo "API iniciando..."
if [ -f "$BACKEND_PATH/seed-corpus.py" ]; then
  sudo -u $WEB_USER $VENV_PATH/bin/python $BACKEND_PATH/seed-corpus.py --rebuild || echo "⚠️ seed falló, via API..."
fi
curl -s -X POST http://127.0.0.1:8000/api/admin/seed-corpus | head -20 || true
sleep 3
curl -s http://127.0.0.1:6333/collections/abogado_gratis_legal | jq '.result.points_count // .result.status // .' 2>/dev/null || curl -s http://127.0.0.1:6333/collections | jq
curl -s http://127.0.0.1:8000/api/health | jq '{status, qdrant, embedding_model, rag_mode}' 2>/dev/null || curl -s http://127.0.0.1:8000/api/health | head -20

# [12/12] Deploy Apache + Frontend
echo -e "${GREEN}⚛️ [12/12] Deploy Apache Frontend build + .htaccess SPA...${NC}"
if [ -f "/opt/abogadogratis/deploy.sh" ]; then
  chmod +x /opt/abogadogratis/deploy.sh
  /opt/abogadogratis/deploy.sh || echo "⚠️ deploy.sh falló"
else
  if [ -d "$REPO_PATH/frontend" ]; then rsync -av --delete $REPO_PATH/frontend/ $FRONTEND_PATH/ --exclude node_modules --exclude .next --exclude build --exclude out; fi
  sudo -u $WEB_USER bash -c "cd $FRONTEND_PATH && npm ci --silent && npm run build" || sudo -u $WEB_USER bash -c "cd $FRONTEND_PATH && npm run build"
  BUILD_SRC="$FRONTEND_PATH/build"; [ -d "$FRONTEND_PATH/out" ] && BUILD_SRC="$FRONTEND_PATH/out"
  mkdir -p $WEB_DIR/build
  rsync -av --delete $BUILD_SRC/ $WEB_DIR/build/ || echo "⚠️ rsync build falló"
  cat > $WEB_DIR/build/.htaccess << 'HTACCESS'
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
  cat > $WEB_DIR/.htaccess << 'HTACCESS2'
<IfModule mod_rewrite.c>
  RewriteEngine On
  RewriteRule ^$ build/ [L]
  RewriteRule ^(.*)$ build/$1 [L]
</IfModule>
HTACCESS2
  chown -R $WEB_USER:$WEB_GROUP $WEB_ROOT $BACKEND_PATH $FRONTEND_PATH 2>/dev/null || true
  chmod -R 750 $BACKEND_PATH
  chmod 640 $BACKEND_PATH/.env 2>/dev/null || true
  systemctl restart abogadogratis-api
  sleep 3
fi

if [ -f "/mnt/data/Makefile" ]; then cp /mnt/data/Makefile /opt/abogadogratis/Makefile; fi

echo -e "${GREEN}🎉 Install Prod CORREGIDO Completado - Fix Network + Bind Check aplicado${NC}"
echo -e "${GREEN}📊 Health:${NC}"
curl -s http://127.0.0.1:8000/api/health | jq 2>/dev/null || curl -s http://127.0.0.1:8000/api/health | head -20
docker ps --filter "name=abogadogratis" --format "table {{.Names}}\t{{.Status}}"
echo -e "${GREEN}🌐 URLs:${NC} https://$DOMAIN"
echo -e "${GREEN}✅ Listo!${NC}"