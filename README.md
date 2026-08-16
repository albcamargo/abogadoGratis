# Abogado Gratis - README Final Apache ISPConfig
## IA para defenderte con RAG Real + Citación Forzada

**Dominio:** https://abogadogratis.corefex.net  
**Servidor:** Ubuntu 24.04 + ISPConfig + Apache 2.4 + MariaDB 10.11 + Qdrant 1.11.3  
**Stack:** FastAPI 0.115 + Next.js 14.2.5 `output: 'export'` (100% estático) + sentence-transformers multilingüe  
**Licencia:** Tecnología cívica CC BY 4.0 - Inspirado en Vía Libre & Data Uruguay  

---

## 📋 Checklist Completo Apache ISPConfig (Sincronizado con tus artefactos actuales)

### ✅ Pre-requisitos ISPConfig
- [ ] Website creado en ISPConfig: `abogadogratis.corefex.net` con Apache, PHP deshabilitado, Let's Encrypt activo
- [ ] `WEB_ROOT = /var/www/abogadogratis.corefex.net/web` existe y `stat -c '%U:%G'` devuelve `web20:client1` (tu usuario ISPConfig)
- [ ] Bases de datos creadas en ISPConfig > Database:
  - `abogadogratis_db` usuario `abogadogratis` pass en `/opt/abogadogratis/api/.env`
- [ ] DNS A record apunta a VPS
- [ ] Puertos 80/443 abiertos, 6333/6334 solo localhost

### 🐍 Backend FastAPI - `/opt/abogadogratis/api/main.py` (tu artefacto actual)
- [ ] `main.py` versión 2.0.0-rag-real-apache con:
  - `sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2` 384 dims Cosine
  - `get_qdrant_results_real()` con `query_points` + `Filter` por vertical (NO scroll dummy)
  - Endpoints: `/api/health`, `/api/casos/clasificar`, `/api/rag/query` (RAG real), `/api/documentos/generar`, `/api/verificar/{id}`, `/api/admin/seed-corpus`
  - Lazy loading modelo para no bloquear systemd
- [ ] `requirements.txt` con `sentence-transformers==3.0.1 qdrant-client==1.11.0 torch CPU`
- [ ] `.env` en `/opt/abogadogratis/api/.env`:
  ```env
  QDRANT_HOST=127.0.0.1
  QDRANT_PORT=6333
  DB_HOST=localhost
  DB_USER=abogadogratis
  DB_PASS=CAMBIA_ESTA_CLAVE
  DB_NAME=abogadogratis_db
  CORS_ORIGINS=https://abogadogratis.corefex.net
  EMBEDDING_MODEL=sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2
  ```
- [ ] `venv` en `/opt/abogadogratis/venv` con `pip install -r requirements.txt`
- [ ] `systemd` service `/etc/systemd/system/abogadogratis-api.service`:
  ```ini
  [Unit]
  Description=Abogado Gratis API - RAG Real
  After=network.target docker.service
  Wants=docker.service

  [Service]
  User=web20
  Group=client1
  WorkingDirectory=/opt/abogadogratis/api
  Environment="PATH=/opt/abogadogratis/venv/bin"
  ExecStart=/opt/abogadogratis/venv/bin/uvicorn main:app --host 127.0.0.1 --port 8000 --workers 2
  Restart=always
  RestartSec=5

  [Install]
  WantedBy=multi-user.target
  ```
- [ ] `systemctl daemon-reload && systemctl enable --now abogadogratis-api`
- [ ] Health: `curl http://127.0.0.1:8000/api/health` debe mostrar `rag_mode: vector_search_real`, `qdrant: ok - abogado_gratis_legal con 20 puntos`, `embedding_model: loaded`

### 🐳 Qdrant - `/opt/qdrant/docker-compose.yml` (artefacto generado)
- [ ] `docker-compose.yml` final con:
  - `image: qdrant/qdrant:v1.11.3`
  - Puertos `127.0.0.1:6333:6333` y `127.0.0.1:6334:6334` solo localhost
  - Volumen persistente `qdrant_storage` bind mount `/opt/qdrant_storage` (no anónimo)
  - Healthcheck `wget --spider http://localhost:6333/healthz` interval 30s
  - Límites RAM 1.5G / 512M reserva para no matar Apache/MariaDB
  - Logging rotación 10m x3
- [ ] `qdrant_config.yaml` con `default_segment_number: 2`, `m:16 ef_construct:100`, `max_search_threads:2`
- [ ] Setup: `cd /opt/qdrant && docker compose up -d`, esperar `healthy`
- [ ] Seed corpus: `/opt/abogadogratis/venv/bin/python seed-corpus.py --rebuild` (20 leyes reales: Constitución Art 23, 15, 29; Ley 1755 Art 14,13; Ley 1480 Art 3,11,42,56; Ley 1266 Art 8,16,4; Ley 1581 Art 8; Ley 769 Art 129,135; Sentencias C-038 2020 fotomultas, T-206 2018 petición, SU-458 2012 caducidad; Circulares SIC, Ley 1328)
- [ ] Verificación: `curl http://127.0.0.1:6333/collections/abogado_gratis_legal | jq .result.points_count` = 20

### ⚛️ Frontend Next.js - 100% Estático Apache
- [ ] `next.config.js` con `output: 'export'`, `trailingSlash: true`, `distDir: 'build'`, `images.unoptimized: true`
- [ ] `app/layout.tsx` premium Inter + JetBrains Mono + grid sutil + footer CC BY 4.0
- [ ] `app/globals.css` (tu artefacto actual) con:
  - Design system `.card-premium`, `.btn-primary`, `.badge-violet`
  - `@media print` con `@page A4 20mm`, membrete `::before` con dominio, `mark` con borde negro, `.grounding-box` con `VERIFICACION DE FUENTES`, `.signature-block` con línea 220px + CC, `.qr-verification` fixed footer, `orphans/widows 3`
- [ ] `app/page.tsx` flujo Clasificar → RAG → Generar con `API_URL = https://abogadogratis.corefex.net/api`
- [ ] `components/DocumentViewer.tsx` con highlight regex Art./Ley/Constitución/SIC y toolbar copiar/.TXT/imprimir bonito
- [ ] `utils/qr.ts` con `qrcode` library, `generateQRDataURL()` que genera DataURL escaneable con URL `/verificar/{id}`, `hashGrounding()` para integridad
- [ ] `app/verificar/[id]/page.tsx` premium con validación hash tiempo real `hashCalculado === grounding_hash`, QR real, botones descargar certificado .txt con grounding + hash + fecha, imprimir certificado con membrete+firma+QR
- [ ] `tailwind.config.js` + `postcss.config.js` + `tsconfig.json`
- [ ] `package.json` con `qrcode`, `next 14.2.5`, `react 18.3.1`
- [ ] Build: `npm ci && npm run build` genera `/build` con `index.html` + `.htaccess` SPA
- [ ] Deploy script `/opt/abogadogratis/deploy.sh` (tu artefacto actual) hace:
  - `git pull`, `rsync backend`, `pip install`, `rsync frontend`, `npm ci && npm run build`
  - `rsync build/ -> /var/www/.../web/build/` + crea `.htaccess` con `RewriteEngine` que no reescribe `/api/` (lo maneja ProxyPass vhost ISPConfig), todo lo demás a `index.html`
  - `chown web20:client1`, `chmod 750`, `systemctl restart abogadogratis-api`, health checks

### 🔒 Apache vHost ISPConfig
- [ ] En ISPConfig > Sites > `abogadogratis.corefex.net` > Options > Apache Directives:
  ```apache
  ProxyPass /api/ http://127.0.0.1:8000/api/
  ProxyPassReverse /api/ http://127.0.0.1:8000/api/
  ProxyPreserveHost On
  RequestHeader set X-Forwarded-Proto "https"
  ```
- [ ] `.htaccess` en `/web/build/.htaccess` y `/web/.htaccess` creados por deploy.sh con `RewriteBase /`, `RewriteCond %{REQUEST_URI} ^/api/ [NC]` + `RewriteRule ^ - [L]` para no tocar api

---

## 🏗️ Diagrama de Arquitectura Final (Apache ISPConfig)

```
┌─────────────────────────────────────────────────────────────────────┐
│ Usuario: https://abogadogratis.corefex.net (Let's Encrypt ISPConfig)          │
│ Browser: Next.js 14 export estático (HTML/CSS/JS) + DocumentViewer   │
│         con highlight Art/Ley + QR real escaneable                   │
└──────────────────────┬──────────────────────────────────────────────┘
                       │ HTTPS 443
┌──────────────────────▼──────────────────────────────────────────────┐
│ Apache 2.4 ISPConfig - /var/www/abogadogratis.corefex.net/web       │
│  - /web/build/.htaccess: SPA routing, no reescribe /api/            │
│  - /web/.htaccess: redirige / -> /build/                            │
│  - ProxyPass /api/ -> 127.0.0.1:8000 (FastAPI)                       │
│  - Let's Encrypt, mod_headers, mod_rewrite                          │
└──────────────────────┬──────────────────────┬───────────────────────┘
                       │ /api/* proxy         │ /* static
┌──────────────────────▼──────────┐  ┌────────▼───────────────────────┐
│ FastAPI 127.0.0.1:8000          │  │ /web/build/index.html +        │
│ main.py 2.0.0-rag-real-apache   │  │ globals.css @media print       │
│  - /api/health: Qdrant + emb    │  │ membrete + firma + QR          │
│  - /api/casos/clasificar: NER   │  │ app/verificar/[id]/page.tsx    │
│  - /api/rag/query: REAL         │  │ con hash tiempo real + cert    │
│    model.encode() ->            │  │ DocumentViewerWithQR           │
│    query_points(vector, Filter) │  └────────────────────────────────┘
│  - /api/documentos/generar      │
│  - /api/verificar/{id}: hash    │
│  - systemd abogadogratis-api    │
└──────────┬──────────┬───────────┘
           │          │
┌──────────▼──┐  ┌────▼─────────────────────────────────────┐
│ MariaDB     │  │ Qdrant Docker - /opt/qdrant/docker-compose│
│ ISPConfig   │  │  - abogadogratis-qdrant container        │
│ abogadogratis_db          │  - 127.0.0.1:6333 REST 6334 gRPC │
│ - casos (id, texto, vertical, empresa)     │  - Volumen persistente: │
│ - documentos_generados (grounding_json, fecha_borrado 30d)│  /opt/qdrant_storage bind │
│ - eventos_plazo (15 días hábiles)          │  - Healthcheck wget /healthz 30s │
│ - corpus_legal (cache fallback)            │  - Collection: abogado_gratis_legal │
└───────────┘  │    20 leyes reales con embeddings 384d    │
               │    paraphrase-multilingual-MiniLM-L12-v2   │
               │  - qdrant_config.yaml optimizado VPS       │
               └─────────────────────────────────────────────┘

Flujo RAG Real:
1. Usuario escribe caso en textarea
2. POST /api/casos/clasificar -> vertical + NER empresa/valor/fecha
3. POST /api/rag/query -> model.encode(consulta) 384d -> query_points con Filter vertical -> retorna 5 artículos con score Cosine + fuente_url oficial
4. POST /api/documentos/generar -> usa grounding para documento legal + explicación humana + checklist + fecha vencimiento 15 días hábiles + guarda MariaDB con fecha_borrado 30 días
5. Frontend muestra DocumentViewer con highlight regex + QR real generado con qrcode.toDataURL(verificacion_url)
6. Print bonito -> @media print globals.css con membrete, firma 220px, QR footer fixed, @page A4
7. Escanea QR -> /verificar/{id} -> GET /api/verificar/{id} consulta MariaDB + calcula hash sha256 grounding_json + compara hash tiempo real cliente -> muestra VÁLIDO + grounding + botón descargar certificado .txt con hash + grounding
```

---

## 💾 Comandos de Backup Completos (Apache ISPConfig)

### Backup Diario Recomendado (cron)

```bash
# Crontab: crontab -e como root
# 0 2 * * * /opt/abogadogratis/backup.sh >> /var/log/abogadogratis/backup.log 2>&1
```

#### 1. MariaDB - Casos + Documentos + Corpus

```bash
#!/bin/bash
BACKUP_DIR="/opt/backups/abogadogratis"
DATE=$(date +%Y%m%d_%H%M%S)
mkdir -p $BACKUP_DIR

# Dump MariaDB ISPConfig (usa credenciales de /opt/abogadogratis/api/.env)
source /opt/abogadogratis/api/.env
mysqldump -h $DB_HOST -u $DB_USER -p$DB_PASS $DB_NAME \
  --single-transaction --routines --triggers --events \
  | gzip > $BACKUP_DIR/mariadb_${DB_NAME}_${DATE}.sql.gz

# Solo estructura por si acaso
mysqldump -h $DB_HOST -u $DB_USER -p$DB_PASS $DB_NAME --no-data \
  | gzip > $BACKUP_DIR/mariadb_schema_${DATE}.sql.gz

# Retención 7 días
find $BACKUP_DIR -name "mariadb_*.sql.gz" -mtime +7 -delete

# Verificación
echo "Backup MariaDB: $(ls -lh $BACKUP_DIR/mariadb_${DB_NAME}_${DATE}.sql.gz)"
# Restaurar: zcat $BACKUP_DIR/mariadb_abogadogratis_db_YYYYMMDD.sql.gz | mysql -h localhost -u abogadogratis -p abogadogratis_db
```

#### 2. Qdrant - Embeddings + Payload (Volumen Persistente)

```bash
# Backup bind mount /opt/qdrant_storage (contiene collection abogado_gratis_legal)
BACKUP_DIR="/opt/backups/abogadogratis"
DATE=$(date +%Y%m%d_%H%M%S)

# Opción A: tar del bind mount (recomendado, rápido)
tar czf $BACKUP_DIR/qdrant_storage_${DATE}.tar.gz \
  --exclude='*.tmp' /opt/qdrant_storage

# Opción B: snapshot Qdrant via API (más limpio, consistente)
curl -X POST http://127.0.0.1:6333/collections/abogado_gratis_legal/snapshots \
  -H 'Content-Type: application/json' -d '{}' | jq
# Snapshot queda en /opt/qdrant_storage/snapshots/
# Listar: curl http://127.0.0.1:6333/collections/abogado_gratis_legal/snapshots | jq
# Copia snapshot a backup
cp /opt/qdrant_storage/snapshots/*.snapshot $BACKUP_DIR/ 2>/dev/null || true

# Backup docker-compose + config
cp /opt/qdrant/docker-compose.yml $BACKUP_DIR/docker-compose_${DATE}.yml
cp /opt/qdrant/qdrant_config.yaml $BACKUP_DIR/qdrant_config_${DATE}.yaml

# Retención 7 días
find $BACKUP_DIR -name "qdrant_*" -mtime +7 -delete

# Restaurar:
# 1. docker compose down
# 2. rm -rf /opt/qdrant_storage/* && tar xzf qdrant_storage_YYYYMMDD.tar.gz -C /
# 3. docker compose up -d
# 4. curl http://127.0.0.1:6333/collections/abogado_gratis_legal | jq .result.points_count # debe ser 20
```

#### 3. Backend + Frontend + Configs

```bash
BACKUP_DIR="/opt/backups/abogadogratis"
DATE=$(date +%Y%m%d_%H%M%S)

# API + venv requirements + .env + main.py actual (tu artefacto)
tar czf $BACKUP_DIR/api_${DATE}.tar.gz \
  /opt/abogadogratis/api/main.py \
  /opt/abogadogratis/api/requirements.txt \
  /opt/abogadogratis/api/.env \
  /opt/abogadogratis/api/seed-corpus.py

# Frontend build + configs (next.config.js output export, globals.css con print, DocumentViewer, qr.ts)
tar czf $BACKUP_DIR/frontend_${DATE}.tar.gz \
  /opt/abogadogratis/frontend/app \
  /opt/abogadogratis/frontend/components \
  /opt/abogadogratis/frontend/utils \
  /opt/abogadogratis/frontend/next.config.js \
  /opt/abogadogratis/frontend/tailwind.config.js \
  /opt/abogadogratis/frontend/package.json

# Apache ISPConfig vhost + .htaccess (generados por deploy.sh)
tar czf $BACKUP_DIR/apache_${DATE}.tar.gz \
  /var/www/abogadogratis.corefex.net/web/build/.htaccess \
  /var/www/abogadogratis.corefex.net/web/.htaccess \
  /etc/apache2/sites-available/abogadogratis.corefex.net.vhost

# Systemd service
cp /etc/systemd/system/abogadogratis-api.service $BACKUP_DIR/systemd_${DATE}.service

# Deploy script actual (tu artefacto)
cp /opt/abogadogratis/deploy.sh $BACKUP_DIR/deploy_${DATE}.sh

# Retención
find $BACKUP_DIR -name "api_*.tar.gz" -o -name "frontend_*.tar.gz" -mtime +7 -delete
```

#### 4. Backup Completo en un Script

```bash
cat > /opt/abogadogratis/backup.sh << 'BACKUP'
#!/bin/bash
set -e
BACKUP_DIR="/opt/backups/abogadogratis"
DATE=$(date +%Y%m%d_%H%M%S)
mkdir -p $BACKUP_DIR
source /opt/abogadogratis/api/.env

echo "[$DATE] Iniciando backup Abogado Gratis Apache..."

# MariaDB
mysqldump -h $DB_HOST -u $DB_USER -p$DB_PASS $DB_NAME --single-transaction | gzip > $BACKUP_DIR/mariadb_${DATE}.sql.gz
echo "✅ MariaDB backup: $BACKUP_DIR/mariadb_${DATE}.sql.gz"

# Qdrant storage bind mount
tar czf $BACKUP_DIR/qdrant_${DATE}.tar.gz /opt/qdrant_storage --exclude='*.tmp' 2>/dev/null
echo "✅ Qdrant storage backup: $BACKUP_DIR/qdrant_${DATE}.tar.gz"

# API + Frontend
tar czf $BACKUP_DIR/app_${DATE}.tar.gz /opt/abogadogratis/api /opt/abogadogratis/frontend/next.config.js /opt/qdrant/docker-compose.yml 2>/dev/null
echo "✅ App backup: $BACKUP_DIR/app_${DATE}.tar.gz"

# Limpieza 7 días
find $BACKUP_DIR -type f -mtime +7 -delete

# Resumen
echo "=== BACKUP COMPLETADO $DATE ==="
ls -lh $BACKUP_DIR/*${DATE}* | awk '{print $9, $5}'
echo "Total backups: $(ls $BACKUP_DIR | wc -l) archivos, $(du -sh $BACKUP_DIR | cut -f1)"
echo "Siguiente backup: cron 0 2 * * *"
BACKUP
chmod +x /opt/abogadogratis/backup.sh
```

#### 5. Restauración Completa (Desastre)

```bash
# Escenario: VPS reinstalado Ubuntu 24 + ISPConfig, necesitas restaurar abogadogratis.corefex.net

# 1. Restaura MariaDB
zcat /opt/backups/abogadogratis/mariadb_20250101.sql.gz | mysql -h localhost -u abogadogratis -p abogadogratis_db

# 2. Restaura Qdrant
mkdir -p /opt/qdrant_storage
tar xzf /opt/backups/abogadogratis/qdrant_20250101.tar.gz -C /
cd /opt/qdrant && docker compose up -d
# Espera healthy: docker inspect --format='{{.State.Health.Status}}' abogadogratis-qdrant
# Verifica: curl http://127.0.0.1:6333/collections/abogado_gratis_legal | jq .result.points_count # 20

# 3. Restaura API + venv
tar xzf /opt/backups/abogadogratis/app_20250101.tar.gz -C /
/opt/abogadogratis/venv/bin/pip install -r /opt/abogadogratis/api/requirements.txt
systemctl daemon-reload && systemctl restart abogadogratis-api
curl http://127.0.0.1:8000/api/health | jq

# 4. Restaura Frontend y deploy Apache
cd /opt/abogadogratis/frontend && npm ci && npm run build
/opt/abogadogratis/deploy.sh
curl -k https://abogadogratis.corefex.net/api/health
```

#### 6. Monitoreo

```bash
# Healthchecks para cron cada 5 min
# */5 * * * * /opt/abogadogratis/healthcheck.sh

cat > /opt/abogadogratis/healthcheck.sh << 'HEALTH'
#!/bin/bash
# Verifica FastAPI + Qdrant + Apache
curl -sf http://127.0.0.1:8000/api/health | jq -e '.qdrant | contains("ok")' > /dev/null || echo "ALERTA Qdrant no ok" | mail -s "Abogado Gratis Qdrant Down" admin@corefex.net
curl -sf http://127.0.0.1:6333/healthz > /dev/null || echo "ALERTA Qdrant healthz" | mail -s "Abogado Gratis Qdrant Down" admin@corefex.net
curl -sfk https://abogadogratis.corefex.net/api/health | jq -e '.status=="ok"' > /dev/null || echo "ALERTA API" | mail -s "Abogado Gratis API Down" admin@corefex.net
HEALTH
chmod +x /opt/abogadogratis/healthcheck.sh
```

---

## 🚀 Deploy Final Apache (Resumen de tu deploy.sh actual)

```bash
# En /opt/abogadogratis/repo (tu repo git)
sudo /opt/abogadogratis/deploy.sh

# Que hace tu deploy.sh (6 pasos):
# [1/6] Git pull origin main como web20
# [2/6] rsync backend -> /opt/abogadogratis/api + pip install requirements.txt (sentence-transformers + qdrant-client)
# [3/6] rsync frontend -> /opt/abogadogratis/frontend + npm ci && npm run build (output export -> /build)
#       + rsync /build -> /var/www/abogadogratis.corefex.net/web/build + crea .htaccess SPA con RewriteCond %{REQUEST_URI} ^/api/ [NC] -> no reescribe api
# [4/6] chown web20:client1 + chmod 750 api + 640 .env
# [5/6] systemctl restart abogadogratis-api + sleep 3 + is-active
# [6/6] curl health checks: 127.0.0.1:8000/health, https://abogadogratis.corefex.net/api/health, https://abogadogratis.corefex.net/
```

---

## 📦 Estructura Final de Archivos (Sincronizada con artefactos)

```
/opt/abogadogratis/
├── api/
│   ├── main.py (2.0.0-rag-real-apache, query_points + embeddings reales, 719 líneas, tu artefacto actual)
│   ├── requirements.txt (fastapi, uvicorn, pymysql, qdrant-client 1.11.0, sentence-transformers 3.0.1, torch CPU)
│   ├── .env (DB, Qdrant, CORS, EMBEDDING_MODEL)
│   └── seed-corpus.py (20 leyes reales con embeddings multilingües)
├── frontend/
│   ├── app/
│   │   ├── layout.tsx (Inter + JetBrains Mono + grid + footer CC BY 4.0)
│   │   ├── page.tsx (Clasificar -> RAG -> Generar con API_URL)
│   │   ├── globals.css (tu artefacto actual, @media print con membrete, firma 220px, QR footer, @page A4)
│   │   ├── components/
│   │   │   ├── DocumentViewer.tsx (highlight Art/Ley/Constitución/SIC + toolbar copiar/.TXT/print bonito)
│   │   │   └── DocumentViewerWithQR.tsx (QR real + print-area)
│   │   └── verificar/[id]/page.tsx (premium con hash tiempo real + QR real + certificado .txt)
│   ├── utils/qr.ts (generateQRDataURL, hashGrounding, useQRCode hook, qrcode library)
│   ├── next.config.js (output: 'export', trailingSlash, distDir: 'build', images.unoptimized)
│   ├── tailwind.config.js + postcss.config.js + tsconfig.json
│   └── package.json (next 14.2.5, qrcode, @types/qrcode)
├── venv/ (Python 3.11 venv con sentence-transformers)
├── repo/ (git repo, origen de deploy.sh)
├── deploy.sh (tu artefacto actual, 6 pasos Apache)
├── backup.sh + healthcheck.sh

/opt/qdrant/
├── docker-compose.yml (FINAL con volumen persistente bind /opt/qdrant_storage, healthcheck wget /healthz, límites 1.5G RAM, ports 127.0.0.1:6333/6334)
├── qdrant_config.yaml (default_segment_number 2, m 16, max_search_threads 2)
└── setup-qdrant-apache.sh (setup inicial)

/opt/qdrant_storage/ (bind mount volumen persistente Qdrant, 20 puntos abogado_gratis_legal)

/var/www/abogadogratis.corefex.net/web/
├── build/ (Next.js export estático)
│   ├── index.html + _next/ + .htaccess SPA (no reescribe /api/)
│   └── verificar/[id]/index.html (estático con QR)
└── .htaccess (redirige / -> /build/)

/opt/backups/abogadogratis/
├── mariadb_*.sql.gz
├── qdrant_*.tar.gz + snapshots
├── api_*.tar.gz + frontend_*.tar.gz + apache_*.tar.gz
```

---

## 🔐 Seguridad & Privacidad (Vía Libre)

- **Procesamiento efímero:** `documentos_generados.fecha_borrado = NOW() + 30 días`, `/api/verificar/{id}` retorna 404 después de borrado, QR deja de validar
- **No PII en logs:** FastAPI no loggea `texto_original` completo, solo vertical
- **Citación forzada:** `grounding_json` con `fuente_url` oficial (Corte Constitucional, SIC), nunca inventa artículos, validado con `hashGrounding` tiempo real
- **Apache ISPConfig:** Qdrant solo localhost, TLS Let's Encrypt, `.htaccess` niega `.(env|log|ini)`, ProxyPass solo `/api/`
- **CC BY 4.0:** Tecnología cívica, código abierto, inspirado Vía Libre & Data Uruguay

---

## 📞 Soporte

- Logs API: `journalctl -u abogadogratis-api -f`
- Logs Qdrant: `docker logs -f abogadogratis-qdrant` o `cd /opt/qdrant && docker compose logs -f`
- Logs Apache ISPConfig: `tail -f /var/log/ispconfig/httpd/abogadogratis.corefex.net/error.log`
- Health: `curl -k https://abogadogratis.corefex.net/api/health | jq` + `curl http://127.0.0.1:6333/healthz`
- Backup: `/opt/backups/abogadogratis/` + `crontab -l`

**¡Listo para defenderte con IA que sí cita la ley!** §
