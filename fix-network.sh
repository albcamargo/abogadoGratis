#!/bin/bash
# fix-network.sh - Fix para error network abogadogratis-network gateway invalid
# Error: invalid network config: invalid gateway 172.20.0.1: parent subnet invalid Prefix doesn't contain this address
# Causa: ipam.config tenía subnet y gateway como dos entradas separadas (- subnet / - gateway) en vez de una sola

set -e
echo "🔧 Fix network abogadogratis-network - Abogado Gratis"
cd /opt/qdrant || cd /opt/abogadogratis/qdrant 2>/dev/null || cd /opt/abogadogratis 2>/dev/null || true

# 1. Detener y eliminar network con error
echo "🛑 Eliminando contenedores y network con error..."
docker compose -f docker-compose.prod.yml down -v 2>/dev/null || true
docker network rm abogadogratis-network 2>/dev/null || true
docker network prune -f 2>/dev/null || true

# 2. Verificar y corregir docker-compose.prod.yml
echo "📝 Verificando docker-compose.prod.yml..."
if [ -f "docker-compose.prod.yml" ]; then
  COMPOSE_FILE="docker-compose.prod.yml"
elif [ -f "/opt/qdrant/docker-compose.prod.yml" ]; then
  COMPOSE_FILE="/opt/qdrant/docker-compose.prod.yml"
elif [ -f "/opt/abogadogratis/qdrant/docker-compose.prod.yml" ]; then
  COMPOSE_FILE="/opt/abogadogratis/qdrant/docker-compose.prod.yml"
else
  echo "❌ No se encontró docker-compose.prod.yml"
  exit 1
fi

echo "Archivo: $COMPOSE_FILE"
# Fix: asegurar que subnet y gateway están en misma entrada ipam.config
# Antes (MAL):
#   config:
#     - subnet: 172.20.0.0/16
#     - gateway: 172.20.0.1
# Después (BIEN):
#   config:
#     - subnet: 172.20.0.0/16
#       gateway: 172.20.0.1

if grep -q "172.20.0.1" "$COMPOSE_FILE"; then
  # Si está mal separado, corrige
  sed -i 's/- subnet: 172.20.0.0\/16\n        - gateway: 172.20.0.1/- subnet: 172.20.0.0\/16\n          gateway: 172.20.0.1/g' "$COMPOSE_FILE" 2>/dev/null || true
  # Usando python para fix robusto
  python3 -c "
import pathlib
p=pathlib.Path('$COMPOSE_FILE')
t=p.read_text()
t=t.replace('- subnet: 172.20.0.0/16\n        - gateway: 172.20.0.1', '- subnet: 172.20.0.0/16\n          gateway: 172.20.0.1')
t=t.replace('- subnet: 172.20.0.0/16\n      - gateway: 172.20.0.1', '- subnet: 172.20.0.0/16\n        gateway: 172.20.0.1')
p.write_text(t)
print('Fixed ipam config')
"
fi

echo "✅ Config corregido:"
grep -A2 "ipam:" "$COMPOSE_FILE" | head -10

# 3. Asegurar directorios bind existen
echo "📁 Creando directorios bind..."
sudo mkdir -p /opt/qdrant_storage /opt/redis_data /opt/backups/abogadogratis /var/log/abogadogratis
sudo chown -R 1000:1000 /opt/qdrant_storage /opt/redis_data 2>/dev/null || true
sudo chmod 750 /opt/qdrant_storage /opt/redis_data

# 4. Levantar prod de nuevo
echo "🚀 Levantando prod corregido..."
cd $(dirname $COMPOSE_FILE)
docker compose -f $(basename $COMPOSE_FILE) up -d
sleep 10
docker ps --filter name=abogadogratis
docker network inspect abogadogratis-network | grep -A5 -B5 "172.20.0.1" | head -20
curl -s http://127.0.0.1:6333/healthz && echo " ✅ Qdrant ok" || echo " ❌ Qdrant no responde aún"
redis-cli -h 127.0.0.1 -p 6379 ping 2>/dev/null && echo " ✅ Redis PONG" || echo " ⚠️ Redis no responde"

echo "🎉 Fix completado. Ahora ejecuta:"
echo "  cd /opt/abogadogratis && make prod-status"
echo "  make prod-logs"
