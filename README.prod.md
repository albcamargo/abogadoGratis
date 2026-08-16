# README.prod.md - Abogado Gratis - Producción Final Qdrant+Redis+Backup cron
## IA para defenderte con RAG Real + Citación Forzada + Cache + Backup Automático

**Dominio:** https://abogadogratis.corefex.net  
**Servidor:** Ubuntu 24.04 + ISPConfig + Apache 2.4 + MariaDB 10.11 + Docker Compose Prod  
**Stack Prod:** FastAPI 0.115 RAG Real `query_points` + Qdrant 1.11.3 20 leyes + Redis 7.4 cache 200MB LRU + Backup cron contenedor 2am + Next.js 14 export 100% estático + Makefile prod  
**Artefactos vigentes:** `main.py` 2.0.0-rag-real-apache, `globals.css` print premium A4 membrete+firma+QR, `deploy.sh` 6 pasos Apache .htaccess SPA, `docker-compose.prod.yml`, `Makefile` prod  
**Licencia:** Tecnología cívica CC BY 4.0 - Vía Libre & Data Uruguay

---

## 🏗️ Diagrama de Arquitectura Prod Qdrant+Redis+Backup cron

```
                                    ┌─────────────────────────────────────────────────┐
                                    │ Usuario: https://abogadogratis.corefex.net      │
                                    │ Browser: Next.js 14 export 100% estático       │
                                    │  - app/page.tsx flujo Clasificar->RAG->Generar │
                                    │  - DocumentViewer highlight Art/Ley/Constitución│
                                    │  - globals.css @media print A4 20mm membrete   │
                                    │    firma 220px + QR footer fixed + @page       │
                                    │  - qr.ts generateQRDataURL() DataURL escaneable │
                                    │  - /verificar/[id] hash tiempo real + cert .txt│
                                    └────────────────────┬────────────────────────────┘
                                                         │ HTTPS 443 Let's Encrypt ISPConfig
┌──────────────────────────────────────────────────────────▼──────────────────────────────────────────────────────────┐
│ Apache 2.4 ISPConfig - /var/www/abogadogratis.corefex.net/web                                       │
│  - /web/build/.htaccess: RewriteEngine, RewriteCond %{REQUEST_URI} ^/api/ [NC] -> no reescribe /api/ (ProxyPass) │
│  - RewriteCond %{REQUEST_FILENAME} -f/-d -> archivo existente, RewriteRule ^ index.html [L] SPA      │
│  - /web/.htaccess: RewriteRule ^$ build/ [L] + RewriteRule ^(.*)$ build/$1 [L]                       │
│  - Apache Directives ISPConfig: ProxyPass /api/ http://127.0.0.1:8000/api/ + ProxyPassReverse         │
│  - mod_headers, mod_rewrite, Let's Encrypt, FilesMatch deny .(env|log|ini)                           │
└──────────────────────────────┬───────────────────────────────┬──────────────────────────────────────┘
                               │ /api/* proxy                  │ /* static build
               ┌───────────────▼───────────────┐   ┌───────────▼─────────────────────────────────┐
               │ FastAPI 127.0.0.1:8000        │   │ /web/build/index.html + _next/ + .htaccess  │
               │ main.py 2.0.0-rag-real-apache │   │ globals.css print premium                   │
               │ + redis_cache.py (opcional)   │   │ verificar/[id]/index.html QR real           │
               │  - /health, /api/health:      │   └─────────────────────────────────────────────┘
               │    Qdrant ok 20 pts,          │
               │    embedding_model loaded     │
               │    384d, redis PONG, rag_mode│
               │    vector_search_real         │
               │  - /api/casos/clasificar:     │
               │    NER regex EMPRESA/VALOR/   │
               │    FECHA + clasificador kw    │
               │  - /api/rag/query REAL:       │
               │    get_cached_rag() Redis 1h  │
               │    -> get_cached_embedding()  │
               │       Redis 24h               │
               │    -> model.encode(consulta) │
               │       384d paraphrase-        │
               │       multilingual-MiniLM-L12 │
               │       -v2 normalize           │
               │    -> query_points(vector,   │
               │       Filter vertical,        │
               │       limit top_k)            │
               │    -> set_cached_rag()       │
               │    Retorna RAGResult norma,  │
               │    articulo, texto, fuente_url│
               │    score Cosine + grounding   │
               │  - /api/documentos/generar:  │
               │    usa RAG grounding +       │
               │    calcula 15 días hábiles   │
               │    + genera doc legal con    │
               │    citas score + exp humana  │
               │    + guarda MariaDB fecha_    │
               │    borrado 30d + eventos     │
               │  - /api/verificar/{id}:      │
               │    hash sha256 grounding_json│
               │    + valida fecha_borrado    │
               │  - /api/admin/seed-corpus:   │
               │    embeddings reales         │
               │  systemd abogadogratis-api   │
               └──────┬──────────┬──────────┬──┘
                      │          │          │
         ┌────────────▼──┐ ┌─────▼──────────────┐  ┌────────▼─────────────────────────────────────────┐
         │ MariaDB       │ │ Redis 7.4 cache    │  │ Docker Compose Prod - /opt/qdrant/docker-      │
         │ ISPConfig     │ │ abogadogratis-redis│  │ compose.prod.yml                               │
         │ abogadogratis_db         │ 127.0.0.1:6379     │  - Qdrant 127.0.0.1:6333/6334 solo localhost  │
         │ - casos (id, texto,      │ - redis_data bind  │    Volumen persistente /opt/qdrant_storage  │
         │   vertical, empresa,     │   /opt/redis_data  │    bind mount, no anónimo, healthcheck wget │
         │   estado, created_at)    │ - maxmemory 200mb  │    /healthz 30s, límites 1.5G RAM           │
         │ - documentos_generados   │   LRU, save 3600 1 │    Collection abogado_gratis_legal 20 leyes │
         │   (grounding_json,       │   300 100, dbfile  │    reales: Constitución Art 23,15,29; Ley  │
         │   fecha_borrado 30d,     │   dump.rdb, no AOF │    1755 Art 14,13; Ley 1480 Art 3,11,42,56;  │
         │   created_at, id, caso)  │ - Cache:           │    Ley 1266 Art 8,16,4; Ley 1581 Art 8; Ley  │
         │ - eventos_plazo (15 días │   embedding:{hash} │    769 Art 129,135; Sentencias C-038 2020    │
         │   hábiles, tipo_evento)  │   TTL 24h vector   │    fotomultas, T-206 2018 petición, SU-458   │
         │ - corpus_legal (fallback)│   rag:{vertical}:  │    2012 caducidad; Circulares SIC, Ley 1328 │
         │                          │   {hash} TTL 1h    │  - Redis 7.4-alpine 127.0.0.1:6379 solo local │
         │                          │   resultados RAG   │    redis.conf maxmemory 200MB LRU,         │
         │                          │ - Healthcheck      │    persistencia RDB, cache embeddings 24h    │
         │                          │   redis-cli ping   │    + RAG 1h, redis_cache.py integrado main.py│
         │                          │                    │  - Backup cron contenedor abogadogratis-backup│
         │                          │                    │    alpine:3.20 + mysql-client+curl+redis+bash│
         │                          │                    │    Cron interno 0 2 * * * backup-cron.sh 2am │
         │                          │                    │    Hace: MariaDB dump via gateway 172.20.0.1 │
         │                          │                    │    (host Ubuntu ISPConfig), Qdrant snapshots  │
         │                          │                    │    POST /collections/.../snapshots API + tar │
         │                          │                    │    storage + Redis RDB redis-cli --rdb       │
         │                          │                    │    + limpieza retención 7 días, logs /var/log │
         │                          │                    │  - Network abogadogratis-network 172.20.0.0/16│
         │                          │                    │    gateway 172.20.0.1 para backup->MariaDB   │
         └───────────────────────────┘ └──────────────────┘  └──────────────────────────────────────────────┘
                                                              │
                                                              ▼
                                              /opt/backups/abogadogratis/
                                              - mariadb_*.sql.gz (MariaDB ISPConfig)
                                              - qdrant_storage_*.tar.gz + *.snapshot
                                              - redis_dump_*.rdb
                                              - app_*.tar.gz (main.py+compose)

Flujo RAG Prod con Cache:
1. Usuario escribe caso -> POST /api/casos/clasificar -> NER empresa/valor/fecha + vertical (derecho_peticion, consumo, habeas_data, multas, dinero_oculto)
2. POST /api/rag/query -> get_cached_rag() Redis? HIT 1h retorna inmediato sin Qdrant
3. Si MISS: get_cached_embedding()? HIT 24h usa vector, si MISS: model.encode() 384d multilingüe -> set_cached_embedding() 24h
4. query_points(vector, Filter vertical=should[vertical, general], limit top_k, with_payload) Qdrant Cosine real -> scores 0.8x
5. set_cached_rag(vertical, consulta, resultados) TTL 1h
6. POST /api/documentos/generar -> usa grounding citas con score + genera doc legal + exp humana + checklist + fecha 15 días hábiles + guarda MariaDB fecha_borrado 30d
7. Frontend DocumentViewer highlight regex Art./Ley/Constitución/SIC + QR real qrcode.toDataURL(https://abogadogratis.corefex.net/verificar/{id}) + toolbar copiar/.TXT/print bonito globals.css @media print membrete+firma+QR
8. Print -> @page A4 20mm, #print-area::before membrete mono uppercase, mark borde negro, grounding-box border 2px black + ::before VERIFICACION FUENTES, signature-block ::before línea 220px + ::after CC+Fecha, qr-verification fixed footer + qr-placeholder 80px border 2px black, a[href]::after (href)
9. Escanea QR -> /verificar/[id] -> GET /api/verificar/{id} -> hash sha256 grounding_json 8 chars + valida fecha_borrado + muestra VÁLIDO + grounding + botón descargar certificado .txt con hash + grounding + fecha
```

---

## ✅ Checklist Deploy Prod Qdrant+Redis+Backup cron

### Pre-requisitos ISPConfig + Apache (como deploy.sh)
- [ ] Website ISPConfig `abogadogratis.corefex.net` Apache, PHP off, Let's Encrypt on, `WEB_ROOT /var/www/abogadogratis.corefex.net/web` existe, `stat -c '%U:%G'` = `web20:client1`
- [ ] Database ISPConfig `abogadogratis_db` usuario `abogadogratis` pass en `/opt/abogadogratis/api/.env` con `DB_HOST localhost DB_USER abogadogratis DB_PASS ... DB_NAME abogadogratis_db QDRANT_HOST 127.0.0.1 QDRANT_PORT 6333 REDIS_HOST 127.0.0.1 REDIS_PORT 6379 CORS_ORIGINS https://abogadogratis.corefex.net EMBEDDING_MODEL paraphrase-multilingual-MiniLM-L12-v2`
- [ ] DNS A record -> VPS, puertos 80/443 abiertos, 6333/6334/6379 solo 127.0.0.1
- [ ] Apache Directives ISPConfig: `ProxyPass /api/ http://127.0.0.1:8000/api/` + `ProxyPassReverse` + `ProxyPreserveHost On` + `RequestHeader set X-Forwarded-Proto https`

### Backend FastAPI RAG Real + Redis cache - `/opt/abogadogratis/api/main.py` (tu artefacto actual 2.0.0-rag-real-apache)
- [ ] `main.py` con `get_embedding_model()` lazy `SentenceTransformer(paraphrase-multilingual-MiniLM-L12-v2)` 384 dims, `get_qdrant_client()` `QdrantClient(host,port,timeout 10)`, `get_qdrant_results_real()` con `model.encode(consulta, normalize_embeddings=True).tolist()` + `Filter(should=[FieldCondition(key=verticales, MatchAny), FieldCondition general])` + `query_points(query=vector, query_filter, limit, with_payload)` retorna `RAGResult` score Cosine, fallback corpus base keywords si Qdrant vacío, `init_db()` crea 4 tablas MariaDB
- [ ] `redis_cache.py` opcional integrado: `get_redis_client()` `redis.Redis(host,port,db,socket_timeout 2)`, `_hash_text sha256 16 chars`, `get_cached_embedding` key `embedding:{hash}` TTL 24h, `set_cached_embedding`, `get_cached_rag` key `rag:{vertical}:{hash}` TTL 1h, `set_cached_rag`, `clear_cache`
- [ ] `requirements.txt`: `fastapi==0.115.0 uvicorn[standard]==0.30.6 python-multipart==0.0.9 python-dotenv==1.0.1 pymysql==1.1.1 qdrant-client==1.11.0 sentence-transformers==3.0.1 cryptography==43.0.0 torch==2.3.0 --index-url https://download.pytorch.org/whl/cpu redis==5.0.5`
- [ ] `seed-corpus.py` 20 leyes reales con `source oficial corteconstitucional.gov.co, funcionpublica.gov.co, sic.gov.co, movilidadbogota.gov.co`, embeddings batch 8, payload `norma, articulo, texto, fuente_url, verticales, vigencia, texto_completo`, test `query_points` prueba "EPS no responde"
- [ ] `venv` `/opt/abogadogratis/venv/bin/pip install -r requirements.txt`
- [ ] `systemd` `/etc/systemd/system/abogadogratis-api.service` User web20 Group client1 WorkingDirectory /opt/abogadogratis/api Environment PATH venv ExecStart uvicorn main:app --host 127.0.0.1 --port 8000 --workers 2 Restart always After network.target docker.service Wants docker.service
- [ ] `systemctl daemon-reload && systemctl enable --now abogadogratis-api && systemctl is-active`
- [ ] Health local: `curl http://127.0.0.1:8000/health | jq {status, qdrant, embedding_model, rag_mode}` debe `qdrant ok - abogado_gratis_legal con 20 puntos`, `embedding_model loaded - ... dim 384`, `rag_mode vector_search_real`

### Docker Compose Prod - `/opt/qdrant/docker-compose.prod.yml` (Qdrant+Redis+Backup)
- [ ] `docker-compose.prod.yml` con 3 services:
  - `qdrant` image `qdrant/qdrant:v1.11.3` container `abogadogratis-qdrant` restart unless-stopped ports `127.0.0.1:6333:6333` `127.0.0.1:6334:6334` volumes `qdrant_storage:/qdrant/storage` bind `/opt/qdrant_storage`, `./qdrant_config.yaml:/qdrant/config/production.yaml:ro`, `/var/log/abogadogratis:/var/log/abogadogratis`, `/opt/backups/abogadogratis:/backups`, env `QDRANT__SERVICE__HTTP_PORT 6333 GRPC 6334 STORAGE_PATH /qdrant/storage SNAPSHOTS_PATH /qdrant/storage/snapshots OPTIMIZERS DEFAULT_SEGMENT_NUMBER 2 HNSW M 16 EF_CONSTRUCT 100 LOG_LEVEL INFO PERFORMANCE MAX_SEARCH_THREADS 2 OPTIMIZERS MEMMAP_THRESHOLD 20000`, healthcheck `wget --spider http://localhost:6333/healthz interval 30s timeout 10s retries 3 start_period 40s`, deploy limits cpus 1.5 memory 1.5G reservations 0.5 512M, logging json-file max-size 10m max-file 3, network abogadogratis-network
  - `redis` image `redis:7.4-alpine` container `abogadogratis-redis` restart unless-stopped ports `127.0.0.1:6379:6379` volumes `redis_data:/data` bind `/opt/redis_data`, `./redis.conf:/usr/local/etc/redis/redis.conf:ro`, command `redis-server /usr/local/etc/redis/redis.conf`, healthcheck `redis-cli ping interval 20s`, deploy limits 0.5 256M reservations 0.2 64M, logging 5m 3, network
  - `backup` image `alpine:3.20` container `abogadogratis-backup` restart unless-stopped volumes `qdrant_storage:/qdrant/storage:ro`, `redis_data:/redis/data:ro`, `/opt/backups/abogadogratis:/backups`, `/opt/abogadogratis/api/.env:/app/.env:ro`, `./backup-cron.sh:/usr/local/bin/backup-cron.sh:ro`, `/var/log/abogadogratis:/var/log/abogadogratis`, env `BACKUP_DIR /backups DB_HOST 172.20.0.1 QDRANT_HOST qdrant QDRANT_PORT 6333 REDIS_HOST redis REDIS_PORT 6379 RETENTION_DAYS 7 BACKUP_SCHEDULE 0 2 * * *`, entrypoint `sh -c apk add mysql-client curl redis bash; echo 0 2 * * * backup-cron.sh | crontab -; crond -f -l 8`, depends_on qdrant healthy redis healthy, deploy limits 0.3 128M, network
- [ ] `qdrant_config.yaml` storage_path /qdrant/storage snapshots_path /qdrant/storage/snapshots optimizers default_segment_number 2 memmap_threshold 20000 indexing_threshold 10000 flush_interval_sec 30 hnsw_index m 16 ef_construct 100 full_scan_threshold 10000 performance max_search_threads 2 max_optimization_threads 1 update_rate 100 service http_port 6333 grpc 6334 enable_cors false enable_tls false cluster enabled false log_level INFO
- [ ] `redis.conf` bind 0.0.0.0 protected-mode yes port 6379 save 3600 1 300 100 60 10000 dbfilename dump.rdb dir /data maxmemory 200mb maxmemory-policy allkeys-lru hz 10 tcp-keepalive 60 timeout 300 loglevel notice logfile "" appendonly no
- [ ] `backup-cron.sh` set -e BACKUP_DIR DATE RETENTION QDRANT_HOST, mkdir backups, source /app/.env, 1/4 MariaDB mysqldump -h DB_HOST -u DB_USER -pDB_PASS DB_NAME --single-transaction | gzip > mariadb_DATE.sql.gz, 2/4 Qdrant curl POST collections/abogado_gratis_legal/snapshots + cp /qdrant/storage/snapshots/*.snapshot + tar czf qdrant_storage_DATE.tar.gz /qdrant/storage, 3/4 Redis redis-cli -h REDIS_HOST ping PONG && redis-cli --rdb redis_dump_DATE.rdb || cp /redis/data/dump.rdb, 4/4 find mtime +RETENTION -delete, resumen ls backups du -sh
- [ ] Directorios: `mkdir -p /opt/qdrant /opt/qdrant_storage /opt/redis_data /opt/backups/abogadogratis /var/log/abogadogratis` chown 1000:1000 storage
- [ ] Prod up: `cd /opt/qdrant && docker compose -f docker-compose.prod.yml up -d`, esperar 8 intentos healthy, `docker ps --filter name=abogadogratis`, `docker inspect Health`, `curl http://127.0.0.1:6333/healthz`, `redis-cli ping PONG`, `curl http://127.0.0.1:6333/collections/abogado_gratis_legal | jq points_count` = 20 tras seed
- [ ] Seed: `sudo -u web20 /opt/abogadogratis/venv/bin/python /opt/abogadogratis/api/seed-corpus.py --rebuild` o `make seed` o `curl POST /api/admin/seed-corpus`

### Frontend Next.js Export 100% Estático + Print Premium - `globals.css` (tu artefacto actual)
- [ ] `next.config.js` output export trailingSlash distDir build images.unoptimized true
- [ ] `app/layout.tsx` Inter + JetBrains Mono + grid + footer CC BY 4.0
- [ ] `app/globals.css` (tu artefacto actual) :root font-inter mono bg fg muted border card, * border-color, html scroll-behavior antialiased, body font bg fg line-height 1.6, h1-h4 weight 600 letter-spacing -0.02em, .mono, @layer components .card-premium rounded-2xl bg-white border shadow-sm backdrop-blur hover:shadow-md transition, .card-dark rounded-2xl bg-zinc-950 text-white border shadow-lg, .badge inline-flex px-2.5 py-1 rounded-full text-xs font-medium border, .badge-violet bg-violet-50 border-violet-200 text-violet-700, .badge-green, .badge-zinc, .btn-primary inline-flex px-5 py-2.5 rounded-xl bg-black text-white text-sm font-medium hover:bg-zinc-800 active:bg-zinc-900, .btn-violet, .input-premium w-full rounded-xl border bg-white px-4 py-3 text-sm placeholder zinc-400 focus ring-2 black, .textarea-premium min-h 120px resize-none, .animate-in animateIn 0.4s ease-out keyframes translateY 8px, .shimmer gradient 90deg transparent rgba white 0.4, ::-webkit-scrollbar 8px, ::selection bg-black text-white, :focus-visible ring-2 black, @page A4 margin 20mm 18mm 22mm 18mm, @media print html body bg white black 11pt line-height 1.5 print-color-adjust exact, body * visibility hidden, #print-area * visible, #print-area absolute left 0 top 0 width 100% bg white box-shadow none border none radius 0 padding 0 margin 0, .no-print display none, #print-area::before content Abogado Gratis • IA para defenderte • abogadogratis.corefex.net • Tecnologia civica CC BY 4.0 mono 7pt uppercase letter-spacing 0.1em color muted border-bottom 2px solid black padding-bottom 8px margin-bottom 20px, #print-area h3 .doc-title 14pt 800 center uppercase letter-spacing 0.05em margin-bottom 16px black, #print-area pre .legal-text white-space pre-wrap Times New Roman 11pt line-height 1.6 black bg white padding 0 border none, #print-area mark bg #f4f4f5 border 1px solid #d4d4d8 black 700 padding 1px 4px radius 3px, mark bg-violet/blue/amber/green bg #f4f4f5 border 1px solid #000 black, .grounding-box margin-top 24px border 2px solid black padding 12px page-break-inside avoid bg #fafafa ::before content VERIFICACION DE FUENTES - CITACION FORZADA ANTI-ALUCINACION 8pt 800 margin-bottom 8px letter-spacing 0.05em, .signature-block margin-top 48px page-break-inside avoid ::before width 220px border-top 1px solid black margin-bottom 8px ::after content Firma del peticionario \A CC: ___ \A Fecha: attr(data-date) white-space pre 10pt margin-top 8px line-height 1.4, .qr-verification fixed bottom 0 right 0 width 100% border-top 1px solid #d4d4d8 padding-top 10px margin-top 20px display flex justify-content space-between align-items flex-end mono 7pt color muted page-break-inside avoid, .qr-placeholder width 80px height 80px border 2px solid black display flex align-items center justify-content center 6pt text-center bold ::before content QR VERIFICACION, h1-h4 page-break-after avoid, p pre ul page-break-inside avoid orphans 3 widows 3, a[href]::after content ( attr(href) ) 8pt muted, a.badge a.no-url::after content "", .print-only display none @media print block, .letterhead-screen gradient white to #fafaf9 border-bottom 2px solid black relative ::after width 33% height 2px bg #7c3aed
- [ ] `app/page.tsx` flujo clasificar -> RAG -> generar con API_URL https://abogadogratis.corefex.net/api, `components/DocumentViewer.tsx` highlight regex Art./Ley/Constitución/SIC + toolbar copiar/.TXT/print bonito, `utils/qr.ts` qrcode toDataURL escaneable, `app/verificar/[id]/page.tsx` premium hash tiempo real + QR real + certificado .txt con grounding hash fecha
- [ ] `tailwind.config.js` + `postcss.config.js` + `tsconfig.json`, `package.json` qrcode next 14.2.5 react 18.3.1
- [ ] Build: `npm ci && npm run build` genera `/build` index.html + `.htaccess` SPA (deploy.sh o Makefile)
- [ ] `deploy.sh` (tu artefacto actual 6 pasos): git pull web20, rsync backend exclude venv __pycache__ pip install requirements.txt quiet, rsync frontend exclude node_modules .next build out npm ci build, BUILD_SRC build/out rsync -> /var/www/.../web/build/, crea /web/build/.htaccess RewriteEngine RewriteBase / RewriteCond REQUEST_URI ^/api/ NC RewriteRule ^ - [L] RewriteCond REQUEST_FILENAME -f/-d RewriteRule ^ - [L] RewriteRule ^ index.html [L] Header X-Powered-By + Cache-Control, FilesMatch deny .(env|log|ini), /web/.htaccess RewriteRule ^$ build/ [L] + ^(.*)$ build/$1 [L], chown web20:client1 WEB_ROOT BACKEND FRONTEND chmod 750 BACKEND 640 .env, systemctl restart abogadogratis-api sleep 3 is-active, curl health local + public + frontend

### Makefile Prod - `Makefile` (tu artefacto actual actualizado prod)
- [ ] `Makefile` prod final con variables DOMAIN WEB_ROOT BACKEND_PATH FRONTEND_PATH VENV_PATH REPO_PATH QDRANT_DIR STORAGE_DIR REDIS_DIR BACKUP_DIR VENV_BIN PYTHON PIP DOCKER_COMPOSE COMPOSE_PROD docker-compose.prod.yml COMPOSE_SIMPLE docker-compose.yml WEB_USER stat, GREEN YELLOW RED NC, .PHONY
- [ ] Targets: `help` muestra prod Qdrant+Redis+Backup + deploy + operación, `prod-up` mkdir storage redis backups log chown 1000:1000 up -d espera 8 intentos healthy Qdrant Redis docker ps prod-status, `prod-down` down, `prod-restart` restart + status, `prod-status` docker ps table Names Status Ports, inspect Health, curl collections points_count, redis-cli ping PONG, ls backups, `prod-logs` Qdrant 40 Redis 20 Backup 20 + backup-cron.log file, `prod-logs-qdrant` follow 100, `prod-logs-redis`, `prod-logs-backup` follow contenedor + file tail, `prod-backup` docker exec backup-cron.sh tail 30 fallback make backup ls backups, `prod-backup-list` ls -lh sort tail du, `deploy` 6 pasos Apache, `seed` python seed-corpus.py --rebuild fallback curl POST admin/seed-corpus, `backup` host MariaDB mysqldump + Qdrant tar + app, `logs` API journalctl + Qdrant + Apache tail, `health` FastAPI local jq qdrant embedding_model rag_mode + Qdrant healthz + Redis PONG + API pública + prod-status + frontend head, `test-rag` curl POST rag/query

---

## 🚀 Checklist Deploy Prod Paso a Paso

```bash
# 1. Pre-requisitos ISPConfig
# En ISPConfig crea Website abogadogratis.corefex.net Apache PHP off Let's Encrypt on
# Database abogadogratis_db usuario abogadogratis
# DNS A -> VPS

# 2. Directorios prod
sudo mkdir -p /opt/qdrant /opt/qdrant_storage /opt/redis_data /opt/backups/abogadogratis /var/log/abogadogratis /opt/abogadogratis/api /opt/abogadogratis/frontend /opt/abogadogratis/repo
sudo chown -R 1000:1000 /opt/qdrant_storage /opt/redis_data 2>/dev/null || true

# 3. Copia artefactos prod (desde /mnt/data generados)
sudo cp /mnt/data/docker-compose.prod.yml /opt/qdrant/docker-compose.prod.yml
sudo cp /mnt/data/docker-compose.yml /opt/qdrant/docker-compose.yml 2>/dev/null || true
sudo cp /mnt/data/qdrant_config.yaml /opt/qdrant/qdrant_config.yaml
sudo cp /mnt/data/redis.conf /opt/qdrant/redis.conf
sudo cp /mnt/data/backup-cron.sh /opt/qdrant/backup-cron.sh
sudo cp /mnt/data/redis_cache.py /opt/abogadogratis/api/redis_cache.py
sudo cp /mnt/data/Makefile /opt/abogadogratis/Makefile
sudo cp /mnt/data/main.py /opt/abogadogratis/api/main.py
sudo cp /mnt/data/deploy.sh /opt/abogadogratis/deploy.sh
sudo chmod +x /opt/qdrant/backup-cron.sh /opt/abogadogratis/deploy.sh

# 4. .env prod
cat > /opt/abogadogratis/api/.env << 'ENV'
QDRANT_HOST=127.0.0.1
QDRANT_PORT=6333
DB_HOST=localhost
DB_USER=abogadogratis
DB_PASS=CAMBIA_ESTA_CLAVE
DB_NAME=abogadogratis_db
CORS_ORIGINS=https://abogadogratis.corefex.net
EMBEDDING_MODEL=sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2
REDIS_HOST=127.0.0.1
REDIS_PORT=6379
REDIS_DB=0
ENV
chmod 640 /opt/abogadogratis/api/.env
chown web20:client1 /opt/abogadogratis/api/.env 2>/dev/null || true

# 5. Venv + requirements prod
python3 -m venv /opt/abogadogratis/venv
/opt/abogadogratis/venv/bin/pip install --upgrade pip
/opt/abogadogratis/venv/bin/pip install -r /opt/abogadogratis/api/requirements.txt  # incluye sentence-transformers 3.0.1 qdrant-client 1.11.0 redis 5.0.5 torch CPU

# 6. Systemd API
cat > /etc/systemd/system/abogadogratis-api.service << 'SERVICE'
[Unit]
Description=Abogado Gratis API - RAG Real Prod
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
SERVICE
systemctl daemon-reload
systemctl enable --now abogadogratis-api

# 7. Prod up Qdrant+Redis+Backup cron
cd /opt/qdrant
docker compose -f docker-compose.prod.yml up -d
# Espera healthy
for i in {1..8}; do echo "Intento $i"; docker inspect --format='{{.Name}} {{.State.Health.Status}}' abogadogratis-qdrant abogadogratis-redis; sleep 5; done
docker ps --filter name=abogadogratis
curl http://127.0.0.1:6333/healthz && echo " Qdrant ok"
redis-cli -h 127.0.0.1 -p 6379 ping  # PONG
# O con Makefile
cd /opt/abogadogratis && make prod-up

# 8. Seed corpus 20 leyes reales embeddings multilingües
/opt/abogadogratis/venv/bin/python /opt/abogadogratis/api/seed-corpus.py --rebuild
# O make seed
curl http://127.0.0.1:6333/collections/abogado_gratis_legal | jq .result.points_count  # 20

# 9. Health prod
curl http://127.0.0.1:8000/health | jq '{qdrant, embedding_model, rag_mode}'
# qdrant ok - abogado_gratis_legal con 20 puntos, embedding_model loaded dim 384, rag_mode vector_search_real
curl http://127.0.0.1:8000/api/rag/query -H 'Content-Type: application/json' -d '{"vertical":"derecho_peticion","consulta":"EPS no responde 20 días","top_k":3}' | jq '.resultados[] | {norma, articulo, score}'
# scores 0.8x Cosine real
make health
make prod-status

# 10. Frontend build + deploy Apache
cd /opt/abogadogratis/frontend && npm ci && npm run build
sudo /opt/abogadogratis/deploy.sh
# O make deploy
curl -k https://abogadogratis.corefex.net/api/health | jq '{status, qdrant, embedding_model}'
curl -k https://abogadogratis.corefex.net/ | head -n 5

# 11. Backup manual prod + cron host
make prod-backup
# Crontab host: crontab -e
# 0 2 * * * cd /opt/abogadogratis && make backup >> /var/log/abogadogratis/backup.log 2>&1
# 0 2 * * * cd /opt/abogadogratis && make prod-backup >> /var/log/abogadogratis/backup-cron.log 2>&1 (si no usas contenedor cron)
# Contenedor backup ya tiene cron interno 2am

# 12. Logs prod
make prod-logs
make logs-api
journalctl -u abogadogratis-api -f
docker logs -f abogadogratis-qdrant
tail -f /var/log/abogadogratis/backup-cron.log
tail -f /var/log/ispconfig/httpd/abogadogratis.corefex.net/error.log

# 13. Verificación documento con QR
# Genera documento en frontend https://abogadogratis.corefex.net, imprime PDF con membrete+firma+QR, escanea QR -> /verificar/{id}
# make verify ID=abc123
```

---

## 💾 Comandos Backup Prod + Restauración

```bash
# Prod backup manual (dispara contenedor + host)
make prod-backup
# Dentro contenedor: MariaDB dump via gateway 172.20.0.1 + Qdrant snapshots POST API + tar storage + Redis RDB
# Host: MariaDB mysqldump + tar qdrant_storage + app

# Lista backups
make prod-backup-list
ls -lh /opt/backups/abogadogratis/ | sort -k9 | tail -20
du -sh /opt/backups/abogadogratis

# Backup host simple (sin contenedor)
make backup
# MariaDB + Qdrant tar + app 7 días retención

# Restauración desastre
# Qdrant:
tar xzf /opt/backups/abogadogratis/qdrant_storage_20250101_*.tar.gz -C /
cd /opt/qdrant && docker compose -f docker-compose.prod.yml restart qdrant
curl http://127.0.0.1:6333/collections/abogado_gratis_legal | jq .result.points_count  # 20

# Redis:
cp /opt/backups/abogadogratis/redis_dump_*.rdb /opt/redis_data/dump.rdb
cd /opt/qdrant && docker compose -f docker-compose.prod.yml restart redis
redis-cli -h 127.0.0.1 -p 6379 ping

# MariaDB:
zcat /opt/backups/abogadogratis/mariadb_*.sql.gz | mysql -h localhost -u abogadogratis -p abogadogratis_db

# App:
tar xzf /opt/backups/abogadogratis/app_*.tar.gz -C /
/opt/abogadogratis/venv/bin/pip install -r /opt/abogadogratis/api/requirements.txt
systemctl restart abogadogratis-api
make health
```

---

## 🔐 Seguridad & Privacidad Prod

- **Procesamiento efímero:** documentos_generados.fecha_borrado NOW()+30 días, /api/verificar retorna 404 tras borrado, QR deja validar, hash sha256 grounding_json 8 chars para integridad
- **No PII logs:** FastAPI no loggea texto_original completo, solo vertical, score Cosine
- **Citación forzada:** grounding_json con fuente_url oficial corteconstitucional.gov.co, funcionpublica.gov.co, sic.gov.co, movilidadbogota.gov.co, nunca inventa artículos, validado hash tiempo real cliente
- **Apache ISPConfig:** Qdrant 127.0.0.1:6333/6334 solo localhost, Redis 127.0.0.1:6379 solo localhost, TLS Let's Encrypt, .htaccess deny .(env|log|ini), ProxyPass solo /api/
- **Cache Redis:** 200MB LRU, embeddings 24h, RAG 1h, ahorra CPU model.encode() repetido, maxmemory-policy allkeys-lru
- **Backup:** Retención 7 días, snapshots Qdrant API + tar storage + Redis RDB + MariaDB dump, contenedor cron 2am + host cron
- **CC BY 4.0:** Tecnología cívica, código abierto, Vía Libre & Data Uruguay

---

## 📦 Estructura Final Prod (Sincronizada artefactos)

```
/opt/abogadogratis/
├── api/
│   ├── main.py 2.0.0-rag-real-apache query_points Filter vertical embeddings 384d paraphrase-multilingual-MiniLM-L12-v2 (tu artefacto actual)
│   ├── redis_cache.py get_redis_client, _hash_text, get/set cached_embedding 24h, get/set cached_rag 1h, clear_cache
│   ├── requirements.txt fastapi uvicorn pymysql qdrant-client 1.11.0 sentence-transformers 3.0.1 torch CPU redis 5.0.5
│   ├── .env QDRANT_HOST 127.0.0.1 QDRANT_PORT 6333 DB_HOST localhost DB_USER abogadogratis DB_PASS ... DB_NAME ... CORS_ORIGINS ... EMBEDDING_MODEL ... REDIS_HOST 127.0.0.1 REDIS_PORT 6379
│   └── seed-corpus.py 20 leyes reales fuente_url oficial payload norma articulo texto fuente_url verticales vigencia texto_completo embeddings batch 8
├── frontend/
│   ├── app/ layout.tsx Inter+JetBrains Mono grid footer CC BY 4.0, page.tsx flujo clasificar RAG generar API_URL, globals.css (tu artefacto actual print premium), components DocumentViewer highlight regex Art/Ley/Constitución/SIC toolbar copiar/.TXT/print bonito, DocumentViewerWithQR QR real, verificar/[id]/page.tsx premium hash tiempo real + QR real + certificado .txt
│   ├── utils/qr.ts generateQRDataURL qrcode DataURL escaneable, hashGrounding, useQRCode hook
│   ├── next.config.js output export trailingSlash distDir build images.unoptimized true, tailwind.config.js, package.json qrcode next 14.2.5 react 18.3.1
│   └── build/ export estático index.html _next/ .htaccess SPA no reescribe /api/
├── venv/ Python venv sentence-transformers torch CPU redis
├── repo/ git repo origen deploy.sh
├── deploy.sh 6 pasos Apache (tu artefacto actual)
├── Makefile prod final prod-up prod-down prod-restart prod-status prod-logs prod-backup deploy seed backup health test-rag verify (tu artefacto actual actualizado)
├── Makefile.prod.yml alternativa prod
└── backup.sh + healthcheck.sh legacy

/opt/qdrant/
├── docker-compose.prod.yml FINAL prod Qdrant+Redis+Backup cron con volumen persistente bind /opt/qdrant_storage, healthcheck wget /healthz, límites 1.5G RAM, ports 127.0.0.1:6333/6334, network 172.20.0.0/16 gateway 172.20.0.1 (principal)
├── docker-compose.yml simple Qdrant solo (backup)
├── qdrant_config.yaml default_segment_number 2 m 16 max_search_threads 2 optimizado VPS
├── redis.conf bind 0.0.0.0 maxmemory 200mb LRU save RDB no AOF
├── backup-cron.sh MariaDB dump gateway 172.20.0.1 + Qdrant snapshots API + tar storage + Redis RDB + retención 7 días
└── setup-qdrant-apache.sh setup inicial

/opt/qdrant_storage/ bind mount volumen persistente Qdrant 20 puntos abogado_gratis_legal
/opt/redis_data/ bind mount Redis dump.rdb
/opt/backups/abogadogratis/ mariadb_*.sql.gz + qdrant_storage_*.tar.gz + *.snapshot + redis_dump_*.rdb + app_*.tar.gz
/var/log/abogadogratis/ backup.log backup-cron.log qdrant logs
/var/www/abogadogratis.corefex.net/web/build/ Next.js export estático + .htaccess SPA no reescribe /api/ + /web/.htaccess redirige / -> /build/
/etc/systemd/system/abogadogratis-api.service User web20 Group client1 WorkingDirectory /opt/abogadogratis/api PATH venv ExecStart uvicorn main:app --host 127.0.0.1 --port 8000 --workers 2 Restart always After docker
```

---

## 📞 Soporte Prod

- **API:** `journalctl -u abogadogratis-api -f` + `make logs-api` + `curl http://127.0.0.1:8000/health | jq`
- **Qdrant prod:** `docker logs -f abogadogratis-qdrant` + `make prod-logs-qdrant` + `curl http://127.0.0.1:6333/healthz` + `curl http://127.0.0.1:6333/collections/abogado_gratis_legal | jq points_count`
- **Redis prod:** `docker logs -f abogadogratis-redis` + `make prod-logs-redis` + `redis-cli -h 127.0.0.1 -p 6379 ping` + `redis-cli info memory`
- **Backup cron:** `docker logs -f abogadogratis-backup` + `make prod-logs-backup` + `tail -f /var/log/abogadogratis/backup-cron.log` + `ls -lh /opt/backups/abogadogratis/`
- **Apache ISPConfig:** `tail -f /var/log/ispconfig/httpd/abogadogratis.corefex.net/error.log` + `make logs-apache`
- **Health prod:** `make health` + `make prod-status` + `curl -k https://abogadogratis.corefex.net/api/health | jq` + `make test-rag`
- **Backups:** `make prod-backup-list` + `du -sh /opt/backups/abogadogratis`
- **Frontend:** `https://abogadogratis.corefex.net/` + `https://abogadogratis.corefex.net/verificar/{id}` + `make verify ID=abc`

**¡Prod listo para defenderte con RAG real + cache + backup automático!** §
