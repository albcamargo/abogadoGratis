# Makefile - Abogado Gratis - Operación con un solo comando
# Ubuntu 24.04 + ISPConfig + Apache + abogadogratis.corefex.net
# Ubicación: /opt/abogadogratis/Makefile o repo root
# Uso: make help, make deploy, make backup, make logs, make seed

# Variables sincronizadas con tus artefactos actuales
DOMAIN := abogadogratis.corefex.net
WEB_ROOT := /var/www/$(DOMAIN)
WEB_DIR := $(WEB_ROOT)/web
BACKEND_PATH := /opt/abogadogratis/api
FRONTEND_PATH := /opt/abogadogratis/frontend
VENV_PATH := /opt/abogadogratis/venv
REPO_PATH := /opt/abogadogratis/repo
QDRANT_DIR := /opt/qdrant
STORAGE_DIR := /opt/qdrant_storage
BACKUP_DIR := /opt/backups/abogadogratis
VENV_BIN := $(VENV_PATH)/bin
PYTHON := $(VENV_BIN)/python
PIP := $(VENV_BIN)/pip
DOCKER_COMPOSE := docker compose

# Detecta usuario ISPConfig automáticamente (como deploy.sh)
WEB_USER := $(shell stat -c '%U' $(WEB_ROOT) 2>/dev/null || echo web20)
WEB_GROUP := $(shell stat -c '%G' $(WEB_ROOT) 2>/dev/null || echo client1)

# Colores para output
GREEN := \033[0;32m
YELLOW := \033[1;33m
RED := \033[0;31m
NC := \033[0m

.PHONY: help deploy backup logs seed health check qdrant logs-qdrant logs-api logs-apache restart clean build frontend backend install verify test-rag

help: ## Muestra esta ayuda
	@echo "$(GREEN)Abogado Gratis - Makefile Operación$(NC) - $(DOMAIN)"
	@echo "Stack: Ubuntu 24.04 + Apache ISPConfig + FastAPI RAG Real + Qdrant + Next.js export"
	@echo ""
	@echo "$(YELLOW)Comandos principales:$(NC)"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-18s$(NC) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(YELLOW)Artefactos sincronizados:$(NC)"
	@echo "  - main.py 2.0.0-rag-real-apache (query_points + embeddings 384d)"
	@echo "  - globals.css con @media print membrete+firma+QR"
	@echo "  - deploy.sh 6 pasos Apache con .htaccess SPA"
	@echo "  - docker-compose.yml Qdrant volumen persistente + healthcheck"

deploy: ## Deploy completo Apache (equivalente a /opt/abogadogratis/deploy.sh) - hace build + rsync + restart
	@echo "$(GREEN)🚀 Deploy Abogado Gratis - Apache - $(DOMAIN)$(NC)"
	@echo "   Web User: $(WEB_USER):$(WEB_GROUP)"
	@echo "📥 [1/6] Git pull..."
	@cd $(REPO_PATH) && sudo -u $(WEB_USER) git pull origin main || echo "⚠️ Sin git repo"
	@echo "🐍 [2/6] Backend FastAPI con embeddings reales..."
	@if [ -d "$(REPO_PATH)/backend" ]; then rsync -av --delete $(REPO_PATH)/backend/ $(BACKEND_PATH)/ --exclude venv --exclude __pycache__; fi
	@sudo -u $(WEB_USER) $(PIP) install -r $(BACKEND_PATH)/requirements.txt --quiet
	@echo "⚛️ [3/6] Frontend Next.js export estático + .htaccess Apache..."
	@if [ -d "$(REPO_PATH)/frontend" ]; then rsync -av --delete $(REPO_PATH)/frontend/ $(FRONTEND_PATH)/ --exclude node_modules --exclude .next --exclude build --exclude out; fi
	@sudo -u $(WEB_USER) bash -c "cd $(FRONTEND_PATH) && npm ci --silent && npm run build"
	@mkdir -p $(WEB_DIR)/build
	@BUILD_SRC="$(FRONTEND_PATH)/build"; [ -d "$(FRONTEND_PATH)/out" ] && BUILD_SRC="$(FRONTEND_PATH)/out"; rsync -av --delete $$BUILD_SRC/ $(WEB_DIR)/build/
	@echo "📄 Creando .htaccess SPA Apache (reemplaza try_files Nginx)..."
	@cat > $(WEB_DIR)/build/.htaccess <<'HTACCESS'
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
	  Header set Cache-Control "public, max-age=3600" env=STATIC
	</IfModule>
	<FilesMatch "\.(env|log|ini)$$">
	  Require all denied
	</FilesMatch>
	HTACCESS
	@cat > $(WEB_DIR)/.htaccess <<'HTACCESS2'
	<IfModule mod_rewrite.c>
	  RewriteEngine On
	  RewriteRule ^$$ build/ [L]
	  RewriteRule ^(.*)$$ build/$$1 [L]
	</IfModule>
	HTACCESS2
	@echo "🔒 [4/6] Permisos ISPConfig Apache..."
	@chown -R $(WEB_USER):$(WEB_GROUP) $(WEB_ROOT) $(BACKEND_PATH) $(FRONTEND_PATH)
	@chmod -R 750 $(BACKEND_PATH)
	@chmod 640 $(BACKEND_PATH)/.env 2>/dev/null || true
	@echo "🔄 [5/6] Reiniciando API..."
	@systemctl restart abogadogratis-api
	@sleep 3
	@systemctl is-active abogadogratis-api
	@echo "✅ [6/6] Health Check..."
	@curl -s http://127.0.0.1:8000/health | head -20
	@curl -s -k https://$(DOMAIN)/api/health | head -20
	@curl -s -k https://$(DOMAIN)/ | head -n 5
	@echo "$(GREEN)🎉 Deploy Apache completado!$(NC)"
	@echo "   Frontend: https://$(DOMAIN)"
	@echo "   API: https://$(DOMAIN)/api/health"

build: ## Solo build frontend Next.js export (sin rsync ni restart)
	@echo "$(YELLOW)⚛️ Build frontend Next.js export...$(NC)"
	@cd $(FRONTEND_PATH) && npm ci && npm run build
	@echo "$(GREEN)✅ Build completado en $(FRONTEND_PATH)/build$(NC)"

frontend: build ## Alias de build

backend: ## Solo backend pip install + restart API
	@echo "$(YELLOW)🐍 Backend FastAPI...$(NC)"
	@sudo -u $(WEB_USER) $(PIP) install -r $(BACKEND_PATH)/requirements.txt
	@systemctl restart abogadogratis-api
	@sleep 2
	@systemctl is-active abogadogratis-api
	@curl -s http://127.0.0.1:8000/api/health | head -10

seed: ## Carga corpus colombiano real con embeddings multilingües en Qdrant (20 leyes)
	@echo "$(GREEN)🌱 Seed corpus colombiano real con embeddings...$(NC)"
	@echo "   Modelo: paraphrase-multilingual-MiniLM-L12-v2 (384 dims)"
	@echo "   Colección: abogado_gratis_legal"
	@cd $(BACKEND_PATH) && sudo -u $(WEB_USER) $(PYTHON) seed-corpus.py --rebuild || \
	  (echo "$(RED)❌ Falló seed-corpus.py, probando via API...$(NC)" && curl -X POST https://$(DOMAIN)/api/admin/seed-corpus | jq)
	@echo "🔍 Verificando puntos en Qdrant..."
	@curl -s http://127.0.0.1:6333/collections/abogado_gratis_legal | jq '.result.points_count // .result.status // .'
	@echo "$(GREEN)✅ Seed completado - RAG real activo$(NC)"

test-rag: ## Prueba RAG real con embeddings (query_points)
	@echo "$(YELLOW)🧠 Test RAG real con embeddings...$(NC)"
	@curl -s -X POST http://127.0.0.1:8000/api/rag/query \
	  -H 'Content-Type: application/json' \
	  -d '{"vertical":"derecho_peticion","consulta":"Mi EPS no responde hace 20 días","top_k":3}' | jq '.resultados[] | {norma, articulo, score}' | head -20
	@echo ""
	@curl -s -X POST http://127.0.0.1:8000/api/rag/query \
	  -H 'Content-Type: application/json' \
	  -d '{"vertical":"habeas_data","consulta":"Datacrédito reporte injusto","top_k":2}' | jq

backup: ## Backup completo MariaDB + Qdrant storage + app (retención 7 días)
	@echo "$(GREEN)💾 Backup completo Abogado Gratis...$(NC)"
	@mkdir -p $(BACKUP_DIR)
	@DATE=$$(date +%Y%m%d_%H%M%S); \
	echo "📦 MariaDB..."; \
	source $(BACKEND_PATH)/.env 2>/dev/null || true; \
	mysqldump -h $${DB_HOST:-localhost} -u $${DB_USER:-abogadogratis} -p$${DB_PASS:-CAMBIA} $${DB_NAME:-abogadogratis_db} --single-transaction 2>/dev/null | gzip > $(BACKUP_DIR)/mariadb_$${DATE}.sql.gz || echo "⚠️ MariaDB backup falló"; \
	echo "📦 Qdrant storage bind mount $(STORAGE_DIR)..."; \
	tar czf $(BACKUP_DIR)/qdrant_$${DATE}.tar.gz $(STORAGE_DIR) --exclude='*.tmp' 2>/dev/null || echo "⚠️ Qdrant backup falló"; \
	echo "📦 App + configs..."; \
	tar czf $(BACKUP_DIR)/app_$${DATE}.tar.gz $(BACKEND_PATH)/main.py $(BACKEND_PATH)/requirements.txt $(QDRANT_DIR)/docker-compose.yml 2>/dev/null || true; \
	find $(BACKUP_DIR) -type f -mtime +7 -delete; \
	ls -lh $(BACKUP_DIR)/*$${DATE}* | awk '{print $$9, $$5}'; \
	echo "$(GREEN)✅ Backup completado en $(BACKUP_DIR) - Total: $$(du -sh $(BACKUP_DIR) | cut -f1)$(NC)"

backup-list: ## Lista backups existentes
	@ls -lh $(BACKUP_DIR) | tail -20
	@du -sh $(BACKUP_DIR)

logs: ## Logs combinados API + Qdrant + Apache (últimas 100 líneas)
	@echo "$(YELLOW)📜 Logs API (systemd)...$(NC)"
	@journalctl -u abogadogratis-api -n 50 --no-pager
	@echo ""
	@echo "$(YELLOW)📜 Logs Qdrant (docker)...$(NC)"
	@cd $(QDRANT_DIR) && $(DOCKER_COMPOSE) logs --tail 50
	@echo ""
	@echo "$(YELLOW)📜 Logs Apache ISPConfig...$(NC)"
	@tail -20 /var/log/ispconfig/httpd/$(DOMAIN)/error.log 2>/dev/null || tail -20 /var/log/apache2/error.log

logs-api: ## Solo logs FastAPI
	@journalctl -u abogadogratis-api -f

logs-qdrant: ## Solo logs Qdrant docker
	@cd $(QDRANT_DIR) && $(DOCKER_COMPOSE) logs -f --tail 100

logs-apache: ## Solo logs Apache ISPConfig
	@tail -f /var/log/ispconfig/httpd/$(DOMAIN)/error.log 2>/dev/null || tail -f /var/log/apache2/error.log

qdrant: ## Operaciones Qdrant: up, down, restart, status
	@echo "Uso: make qdrant-up | make qdrant-down | make qdrant-restart | make qdrant-status"

qdrant-up: ## Inicia Qdrant con volumen persistente + healthcheck
	@cd $(QDRANT_DIR) && $(DOCKER_COMPOSE) up -d
	@sleep 5
	@docker inspect --format='Estado: {{.State.Health.Status}} - {{.State.Status}}' abogadogratis-qdrant || docker ps | grep qdrant

qdrant-down: ## Detiene Qdrant
	@cd $(QDRANT_DIR) && $(DOCKER_COMPOSE) down

qdrant-restart: ## Reinicia Qdrant
	@cd $(QDRANT_DIR) && $(DOCKER_COMPOSE) restart
	@sleep 5
	@curl -s http://127.0.0.1:6333/healthz || echo "Esperando healthz..."

qdrant-status: ## Estado Qdrant + collections
	@docker ps | grep qdrant || echo "Qdrant no corriendo"
	@docker inspect --format='Health: {{.State.Health.Status}}' abogadogratis-qdrant 2>/dev/null || true
	@curl -s http://127.0.0.1:6333/ | jq
	@curl -s http://127.0.0.1:6333/collections | jq

health: ## Health check completo API + Qdrant + Apache
	@echo "$(GREEN)🏥 Health Check Abogado Gratis - $(DOMAIN)$(NC)"
	@echo "1. FastAPI local:"
	@curl -s http://127.0.0.1:8000/health | jq '{status, qdrant, embedding_model, rag_mode}' || curl -s http://127.0.0.1:8000/health
	@echo ""
	@echo "2. API pública:"
	@curl -sk https://$(DOMAIN)/api/health | jq '{status, server, database, qdrant, embedding_model}' || curl -sk https://$(DOMAIN)/api/health
	@echo ""
	@echo "3. Qdrant:"
	@curl -s http://127.0.0.1:6333/healthz && echo " ✅ Qdrant healthz ok" || echo " ❌ Qdrant healthz falló"
	@curl -s http://127.0.0.1:6333/collections/abogado_gratis_legal | jq '{points_count: .result.points_count, status: .result.status}' 2>/dev/null || curl -s http://127.0.0.1:6333/collections | jq
	@echo ""
	@echo "4. Frontend:"
	@curl -sk https://$(DOMAIN)/ | head -n 3

check: health ## Alias de health

restart: ## Restart API + Qdrant
	@systemctl restart abogadogratis-api
	@cd $(QDRANT_DIR) && $(DOCKER_COMPOSE) restart
	@sleep 3
	@$(MAKE) health

verify: ## Verifica un documento por ID (uso: make verify ID=abc123)
	@if [ -z "$(ID)" ]; then echo "Uso: make verify ID=abc123def456"; exit 1; fi
	@curl -s https://$(DOMAIN)/api/verificar/$(ID) | jq '{valido, grounding_hash, verificacion_url, mensaje}'
	@echo "Ver en: https://$(DOMAIN)/verificar/$(ID)"

install: ## Instala deps venv + npm (primera vez)
	@echo "$(YELLOW)📦 Instalando dependencias...$(NC)"
	@$(PIP) install -r $(BACKEND_PATH)/requirements.txt
	@cd $(FRONTEND_PATH) && npm ci
	@echo "$(GREEN)✅ Deps instaladas$(NC)"

clean: ## Limpia builds frontend
	@rm -rf $(FRONTEND_PATH)/build $(FRONTEND_PATH)/out $(FRONTEND_PATH)/.next
	@echo "🧹 Builds limpiados"

ps: ## Estado procesos
	@systemctl status abogadogratis-api --no-pager -l | head -20
	@docker ps | grep qdrant
	@echo ""
	@ps aux | grep -E "uvicorn|qdrant" | grep -v grep | head -10

# Targets privados para deploy.sh compatibilidad
_deploy-htaccess: ## Crea .htaccess SPA Apache (interno)
	@cat > $(WEB_DIR)/build/.htaccess <<'HT'
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
	HT
