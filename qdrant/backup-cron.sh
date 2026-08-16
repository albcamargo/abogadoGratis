#!/bin/bash
# backup-cron.sh - Backup automático dentro de contenedor backup
# Ejecutado por cron 2am diario en contenedor abogadogratis-backup
# Hace: MariaDB dump + Qdrant snapshots + Redis RDB + limpieza 7 días

set -e

BACKUP_DIR=${BACKUP_DIR:-/backups}
DATE=$(date +%Y%m%d_%H%M%S)
RETENTION_DAYS=${RETENTION_DAYS:-7}
DB_HOST=${DB_HOST:-172.20.0.1}
QDRANT_HOST=${QDRANT_HOST:-qdrant}
QDRANT_PORT=${QDRANT_PORT:-6333}
REDIS_HOST=${REDIS_HOST:-redis}

mkdir -p $BACKUP_DIR /var/log/abogadogratis

echo "[$DATE] Iniciando backup automático Abogado Gratis prod..."

# Carga .env para credenciales MariaDB
if [ -f /app/.env ]; then
    source /app/.env
fi

# 1. MariaDB dump (desde contenedor, conecta a gateway 172.20.0.1 que es host Ubuntu ISPConfig)
echo "📦 [1/4] MariaDB ${DB_NAME}..."
if [ -n "$DB_USER" ] && [ -n "$DB_PASS" ]; then
    mysqldump -h $DB_HOST -u $DB_USER -p$DB_PASS $DB_NAME --single-transaction --routines --triggers 2>/dev/null | gzip > $BACKUP_DIR/mariadb_${DATE}.sql.gz && \
        echo "✅ MariaDB backup: $(du -h $BACKUP_DIR/mariadb_${DATE}.sql.gz | cut -f1)" || \
        echo "⚠️ MariaDB backup falló (normal si DB_HOST no accesible desde contenedor, usa backup.sh del host)"
else
    echo "⚠️ Credenciales DB no encontradas en .env, saltando MariaDB"
fi

# 2. Qdrant snapshots via API
echo "📦 [2/4] Qdrant snapshots..."
for COLLECTION in abogado_gratis_legal; do
    curl -s -X POST http://$QDRANT_HOST:$QDRANT_PORT/collections/$COLLECTION/snapshots -H 'Content-Type: application/json' -d '{}' | \
        grep -q "snapshot" && echo "✅ Snapshot $COLLECTION creado" || echo "⚠️ Snapshot $COLLECTION falló"
    # Copia snapshots del volumen montado a backup dir
    cp /qdrant/storage/snapshots/$COLLECTION/*.snapshot $BACKUP_DIR/ 2>/dev/null || true
done
# Tar del storage completo como respaldo adicional
tar czf $BACKUP_DIR/qdrant_storage_${DATE}.tar.gz /qdrant/storage --exclude='*.tmp' --exclude='snapshots/*.tmp' 2>/dev/null && \
    echo "✅ Qdrant storage tar: $(du -h $BACKUP_DIR/qdrant_storage_${DATE}.tar.gz | cut -f1)" || true

# 3. Redis RDB dump
echo "📦 [3/4] Redis RDB..."
if redis-cli -h $REDIS_HOST -p 6379 ping 2>/dev/null | grep -q PONG; then
    redis-cli -h $REDIS_HOST -p 6379 --rdb $BACKUP_DIR/redis_dump_${DATE}.rdb 2>/dev/null && \
        echo "✅ Redis RDB backup: $(du -h $BACKUP_DIR/redis_dump_${DATE}.rdb | cut -f1)" || \
        (cp /redis/data/dump.rdb $BACKUP_DIR/redis_dump_${DATE}.rdb 2>/dev/null && echo "✅ Redis RDB copiado") || \
        echo "⚠️ Redis backup falló"
else
    echo "⚠️ Redis no responde, saltando"
fi

# 4. Limpieza retención
echo "🧹 [4/4] Limpieza retención ${RETENTION_DAYS} días..."
find $BACKUP_DIR -type f -name "mariadb_*.sql.gz" -mtime +$RETENTION_DAYS -delete 2>/dev/null || true
find $BACKUP_DIR -type f -name "qdrant_*.tar.gz" -mtime +$RETENTION_DAYS -delete 2>/dev/null || true
find $BACKUP_DIR -type f -name "*.snapshot" -mtime +$RETENTION_DAYS -delete 2>/dev/null || true
find $BACKUP_DIR -type f -name "redis_dump_*.rdb" -mtime +$RETENTION_DAYS -delete 2>/dev/null || true

# Resumen
echo "=== BACKUP PROD COMPLETADO $DATE ==="
ls -lh $BACKUP_DIR/*${DATE}* 2>/dev/null | awk '{print $9, $5}' || echo "No hay archivos nuevos (normal si MariaDB no accesible desde contenedor)"
echo "Total backups: $(ls $BACKUP_DIR 2>/dev/null | wc -l) archivos, $(du -sh $BACKUP_DIR 2>/dev/null | cut -f1)"
echo "Espacio disco: $(df -h $BACKUP_DIR | tail -1)"
echo ""
echo "Para restaurar:"
echo "  Qdrant: tar xzf qdrant_storage_*.tar.gz -C / && docker compose -f docker-compose.prod.yml restart qdrant"
echo "  MariaDB: zcat mariadb_*.sql.gz | mysql -h localhost -u abogadogratis -p abogadogratis_db"
echo "  Redis: cp redis_dump_*.rdb /opt/redis_data/dump.rdb && docker compose restart redis"
