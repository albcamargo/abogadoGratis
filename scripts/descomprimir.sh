#!/bin/bash
# descomprimir.sh - Instrucciones para descomprimir zip en /opt/abogadogratis
set -e
ZIP_FILE=${1:-/tmp/abogadogratis-prod-package.zip}
echo "Descomprimiendo $ZIP_FILE en /opt/ para crear /opt/abogadogratis/ ..."
sudo apt install -y unzip
sudo mkdir -p /opt
sudo unzip -o $ZIP_FILE -d /opt/
# El zip contiene carpeta abogadogratis/
# Si se descomprimió como /opt/abogadogratis-prod-package renombrar:
if [ -d "/opt/abogadogratis-prod-package" ] && [ ! -d "/opt/abogadogratis" ]; then
  sudo mv /opt/abogadogratis-prod-package /opt/abogadogratis
fi
sudo chown -R root:root /opt/abogadogratis
sudo chmod +x /opt/abogadogratis/install-prod.sh
sudo chmod +x /opt/abogadogratis/deploy.sh
sudo chmod +x /opt/abogadogratis/qdrant/backup-cron.sh
ls -lh /opt/abogadogratis/
echo "Listo. Ahora ejecuta:"
echo "  cd /opt/abogadogratis && sudo ./install-prod.sh"
