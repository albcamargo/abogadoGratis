# Instalación Prod - Zip /opt/abogadogratis

Este zip contiene TODA la estructura para ejecutar install-prod.sh en 1 comando - 12 pasos.

## 1. Descomprimir en /opt/abogadogratis

En tu VPS Ubuntu 24.04 con ISPConfig:

```bash
# Sube el zip abogadogratis-prod-package.zip a /tmp
sudo apt install -y unzip
sudo mkdir -p /opt
sudo unzip /tmp/abogadogratis-prod-package.zip -d /opt/
# Esto crea /opt/abogadogratis/
# Si el zip se descomprimió como /opt/abogadogratis-prod-package, renombra:
sudo mv /opt/abogadogratis-prod-package /opt/abogadogratis
# O si ya está dentro:
sudo mv /opt/abogadogratis/abogadogratis-prod-package/* /opt/abogadogratis/ 2>/dev/null || true

sudo chown -R root:root /opt/abogadogratis
sudo chmod +x /opt/abogadogratis/install-prod.sh
sudo chmod +x /opt/abogadogratis/deploy.sh
sudo chmod +x /opt/abogadogratis/qdrant/backup-cron.sh
ls -lh /opt/abogadogratis/
```

Estructura esperada después de descomprimir:
```
/opt/abogadogratis/
├── install-prod.sh        # Script principal 12 pasos (ejecutar como root)
├── deploy.sh              # Deploy 6 pasos Apache (tu artefacto actual)
├── Makefile               # prod-up, prod-down, prod-logs, prod-backup, deploy, seed, health
├── README.prod.md         # Diagrama arquitectura prod Qdrant+Redis+Backup cron + checklist
├── README.md              # README general
├── api/
│   ├── main.py            # 2.0.0-rag-real-apache query_points + embeddings 384d (tu artefacto)
│   ├── redis_cache.py     # Cache Redis embeddings 24h + RAG 1h
│   ├── seed-corpus.py     # 20 leyes reales colombianas con embeddings multilingües
│   ├── requirements.txt   # fastapi, uvicorn, qdrant-client 1.11.0, sentence-transformers 3.0.1, redis 5.0.5, torch CPU
│   └── .env.example       # Plantilla .env -> copiar a .env y poner pass real DB ISPConfig
├── frontend/
│   ├── app/
│   │   └── globals.css    # @media print A4 20mm membrete+firma 220px+QR footer fixed (tu artefacto)
│   ├── package.json.example
│   └── next.config.js.example
└── qdrant/
    ├── docker-compose.prod.yml  # Prod Qdrant+Redis+Backup cron volumen persistente bind /opt/qdrant_storage + healthcheck
    ├── docker-compose.yml       # Simple Qdrant solo
    ├── qdrant_config.yaml       # Optimizado VPS 2 segmentos, m 16, max_search_threads 2
    ├── redis.conf               # maxmemory 200mb LRU, RDB save
    └── backup-cron.sh           # Cron 2am MariaDB dump gateway + Qdrant snapshots API + Redis RDB + retención 7 días
```

## 2. Pre-requisitos ISPConfig (antes de install-prod.sh)

1. En ISPConfig > Sites > Website > Add new website:
   - Domain: abogadogratis.corefex.net
   - PHP: Disabled
   - SSL + Let's Encrypt: Checked
   - Apache Directives:
```
ProxyPass /api/ http://127.0.0.1:8000/api/
ProxyPassReverse /api/ http://127.0.0.1:8000/api/
ProxyPreserveHost On
RequestHeader set X-Forwarded-Proto "https"
```

2. En ISPConfig > Database > Add:
   - Database: abogadogratis_db
   - User: abogadogratis
   - Pass: el que pondrás en /opt/abogadogratis/api/.env

## 3. Ejecutar install-prod.sh en 1 comando - 12 pasos

```bash
cd /opt/abogadogratis
sudo ./install-prod.sh

# O con opciones:
sudo ./install-prod.sh --domain abogadogratis.corefex.net --repo https://github.com/tuuser/abogadogratis.git --branch main
sudo ./install-prod.sh --skip-ispconfig  # si ya existe website
sudo ./install-prod.sh --skip-docker    # si ya tienes docker

# El script hace:
# [1/12] Sistema base Ubuntu 24.04 + deps (curl, git, python3 venv, nodejs 20, mariadb-client)
# [2/12] Docker + Docker Compose
# [3/12] Directorios /opt/qdrant_storage /opt/redis_data /opt/backups/abogadogratis /var/log/abogadogratis
# [4/12] Check ISPConfig Website /var/www/abogadogratis.corefex.net
# [5/12] Repo git clone/pull
# [6/12] docker-compose.prod.yml + redis.conf + qdrant_config + backup-cron.sh (usa artefactos del zip)
# [7/12] Backend main.py + redis_cache.py + frontend globals.css + .env (genera pass aleatorio si no existe) + requirements.txt
# [8/12] Venv + pip install + npm ci
# [9/12] Systemd abogadogratis-api.service User web20 Group client1
# [10/12] Prod up docker compose -f docker-compose.prod.yml up -d + healthchecks Qdrant healthy Redis healthy
# [11/12] Seed corpus 20 leyes reales embeddings multilingües + Start API + Health local
# [12/12] Deploy Apache Frontend build + .htaccess SPA no reescribe /api/ + chown + restart + health public
```

## 4. Verificación final

```bash
cd /opt/abogadogratis
make health
make prod-status
make prod-logs
curl -k https://abogadogratis.corefex.net/api/health | jq
curl -k https://abogadogratis.corefex.net/ | head -n 5
```

## 5. Comandos Makefile prod

```bash
make prod-up           # Inicia Qdrant+Redis+Backup cron con healthchecks
make prod-down         # Detiene prod
make prod-restart      # Reinicia prod
make prod-status       # Estado Qdrant+Redis+Backup+collections points_count
make prod-logs         # Logs Qdrant 40 + Redis 20 + Backup 20 + backup-cron.log file
make prod-logs-qdrant  # follow Qdrant
make prod-logs-redis   # follow Redis
make prod-logs-backup  # follow Backup cron
make prod-backup       # Backup manual: docker exec backup-cron.sh + make backup host
make prod-backup-list  # Lista backups
make deploy            # Deploy Apache 6 pasos (tu deploy.sh)
make seed              # Seed corpus 20 leyes
make health            # Health API+Qdrant+Redis+Frontend
make test-rag          # Test RAG real query_points
make verify ID=abc123  # Verifica documento
```

## 6. Backups

- Contenedor backup cron interno 2am diario: MariaDB dump via gateway 172.20.0.1 + Qdrant snapshots API + tar storage + Redis RDB -> /opt/backups/abogadogratis
- Host cron adicional: crontab -e -> 0 2 * * * cd /opt/abogadogratis && make prod-backup >> /var/log/abogadogratis/backup.log 2>&1
- Restauración:
```bash
tar xzf /opt/backups/abogadogratis/qdrant_storage_*.tar.gz -C /
cp /opt/backups/abogadogratis/redis_dump_*.rdb /opt/redis_data/dump.rdb
zcat /opt/backups/abogadogratis/mariadb_*.sql.gz | mysql -h localhost -u abogadogratis -p abogadogratis_db
```

¡Listo! Prod Qdrant+Redis+Backup cron + RAG real 384d + print premium membrete+firma+QR en /opt/abogadogratis
