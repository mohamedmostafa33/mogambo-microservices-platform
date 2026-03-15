#!/usr/bin/env bash
set -euo pipefail

#########################################################
# Safe SonarQube installer for Amazon Linux 2023 (EC2)
# Target: c7i-flex.large
# - Avoid curl/curl-minimal conflict
# - Conservative JVM to prevent server hangs
# - Adds 4G swap for stability
# - PostgreSQL local
# - systemd service
#########################################################

# =========================
# Config
# =========================
SONAR_VERSION="10.6.0.92116"
SONAR_ZIP="sonarqube-${SONAR_VERSION}.zip"
SONAR_URL="https://binaries.sonarsource.com/Distribution/sonarqube/${SONAR_ZIP}"

SONAR_HOME="/opt/sonarqube"
SONAR_USER="sonarqube"
SONAR_GROUP="sonarqube"
SONAR_PORT="9000"

DB_NAME="sonarqube"
DB_USER="sonar"
DB_PASS="ChangeMe_StrongPassword_123!"   # <-- غيرها

# Conservative JVM (prevents SSH freeze)
# You can increase later after stable operation
SEARCH_XMS="768m"
SEARCH_XMX="768m"
WEB_XMS="384m"
WEB_XMX="384m"
CE_XMS="384m"
CE_XMX="384m"
CE_WORKERS="1"

SWAP_SIZE_GB="4"

echo "==> [1/14] Update system"
sudo dnf -y update

echo "==> [2/14] Install dependencies (NO curl package to avoid conflict)"
sudo dnf -y install \
  java-17-amazon-corretto-headless \
  wget unzip tar \
  postgresql15 postgresql15-server \
  firewalld

echo "==> [3/14] Create swap (${SWAP_SIZE_GB}G) if not exists"
if ! sudo swapon --show | grep -q '/swapfile'; then
  if [ ! -f /swapfile ]; then
    sudo fallocate -l "${SWAP_SIZE_GB}G" /swapfile || sudo dd if=/dev/zero of=/swapfile bs=1M count=$((SWAP_SIZE_GB*1024))
    sudo chmod 600 /swapfile
    sudo mkswap /swapfile
  fi
  sudo swapon /swapfile
  if ! grep -q '^/swapfile ' /etc/fstab; then
    echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab >/dev/null
  fi
fi
sudo swapon --show
free -h

echo "==> [4/14] Init and start PostgreSQL"
if [ ! -s /var/lib/pgsql/data/PG_VERSION ]; then
  sudo /usr/bin/postgresql-setup --initdb
fi
sudo systemctl enable postgresql
sudo systemctl start postgresql

echo "==> [5/14] Create DB user and DB"
if ! sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='${DB_USER}'" | grep -q 1; then
  sudo -u postgres psql -c "CREATE USER ${DB_USER} WITH ENCRYPTED PASSWORD '${DB_PASS}';"
fi
if ! sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname='${DB_NAME}'" | grep -q 1; then
  sudo -u postgres psql -c "CREATE DATABASE ${DB_NAME} OWNER ${DB_USER};"
fi

# local auth hardening (best effort)
sudo sed -i "s|^host\s\+all\s\+all\s\+127\.0\.0\.1/32\s\+.*|host all all 127.0.0.1/32 scram-sha-256|g" /var/lib/pgsql/data/pg_hba.conf || true
sudo sed -i "s|^host\s\+all\s\+all\s\+::1/128\s\+.*|host all all ::1/128 scram-sha-256|g" /var/lib/pgsql/data/pg_hba.conf || true
sudo systemctl restart postgresql

echo "==> [6/14] Create sonarqube user/group"
if ! getent group "${SONAR_GROUP}" >/dev/null; then
  sudo groupadd --system "${SONAR_GROUP}"
fi
if ! id -u "${SONAR_USER}" >/dev/null 2>&1; then
  sudo useradd --system --home-dir "${SONAR_HOME}" --gid "${SONAR_GROUP}" --shell /sbin/nologin "${SONAR_USER}"
fi

echo "==> [7/14] Download and install SonarQube"
cd /tmp
wget -q --show-progress "${SONAR_URL}" -O "${SONAR_ZIP}"
sudo rm -rf "${SONAR_HOME}" "/opt/sonarqube-${SONAR_VERSION}"
sudo unzip -q -o "/tmp/${SONAR_ZIP}" -d /opt/
sudo mv "/opt/sonarqube-${SONAR_VERSION}" "${SONAR_HOME}"
sudo mkdir -p "${SONAR_HOME}/"{data,temp,logs,extensions}

echo "==> [8/14] Configure SonarQube"
sudo tee "${SONAR_HOME}/conf/sonar.properties" >/dev/null <<EOF
# Network
sonar.web.host=0.0.0.0
sonar.web.port=${SONAR_PORT}

# Database
sonar.jdbc.username=${DB_USER}
sonar.jdbc.password=${DB_PASS}
sonar.jdbc.url=jdbc:postgresql://127.0.0.1:5432/${DB_NAME}

# Paths
sonar.path.data=${SONAR_HOME}/data
sonar.path.temp=${SONAR_HOME}/temp
sonar.path.logs=${SONAR_HOME}/logs

# Conservative JVM (stable first)
sonar.search.javaOpts=-Xms${SEARCH_XMS} -Xmx${SEARCH_XMX} -XX:+HeapDumpOnOutOfMemoryError
sonar.web.javaOpts=-Xms${WEB_XMS} -Xmx${WEB_XMX} -XX:+HeapDumpOnOutOfMemoryError
sonar.ce.javaOpts=-Xms${CE_XMS} -Xmx${CE_XMX} -XX:+HeapDumpOnOutOfMemoryError
sonar.ce.workerCount=${CE_WORKERS}
EOF

# Ensure script mode user
sudo sed -i "s|^#\?RUN_AS_USER=.*|RUN_AS_USER=${SONAR_USER}|g" "${SONAR_HOME}/bin/linux-x86-64/sonar.sh"

echo "==> [9/14] Required kernel/limits (apply only needed keys, NOT sysctl --system)"
sudo tee /etc/sysctl.d/99-sonarqube.conf >/dev/null <<EOF
vm.max_map_count=262144
fs.file-max=131072
EOF
sudo sysctl -w vm.max_map_count=262144
sudo sysctl -w fs.file-max=131072

sudo tee /etc/security/limits.d/99-sonarqube.conf >/dev/null <<EOF
${SONAR_USER} - nofile 131072
${SONAR_USER} - nproc  8192
EOF

echo "==> [10/14] Ownership/permissions"
sudo chown -R "${SONAR_USER}:${SONAR_GROUP}" "${SONAR_HOME}"
sudo chmod -R 750 "${SONAR_HOME}"

echo "==> [11/14] Create systemd service"
sudo tee /etc/systemd/system/sonarqube.service >/dev/null <<EOF
[Unit]
Description=SonarQube service
After=network.target postgresql.service
Wants=postgresql.service

[Service]
Type=forking
User=${SONAR_USER}
Group=${SONAR_GROUP}
ExecStart=${SONAR_HOME}/bin/linux-x86-64/sonar.sh start
ExecStop=${SONAR_HOME}/bin/linux-x86-64/sonar.sh stop
LimitNOFILE=131072
LimitNPROC=8192
TimeoutStartSec=300
Restart=on-failure
RestartSec=15
SuccessExitStatus=143

[Install]
WantedBy=multi-user.target
EOF

echo "==> [12/14] Firewall (OS-level)"
sudo systemctl enable firewalld || true
sudo systemctl start firewalld || true
sudo firewall-cmd --permanent --add-port=${SONAR_PORT}/tcp || true
sudo firewall-cmd --reload || true

echo "==> [13/14] Start SonarQube"
sudo systemctl daemon-reload
sudo systemctl enable sonarqube
sudo systemctl restart sonarqube

echo "==> [14/14] Wait for SonarQube readiness (up to 10 min)"
for i in {1..120}; do
  STATUS="$(curl -s http://127.0.0.1:${SONAR_PORT}/api/system/status || true)"
  if echo "$STATUS" | grep -q '"status":"UP"'; then
    echo "SonarQube is UP"
    break
  fi
  if (( i % 12 == 0 )); then
    echo "Still waiting... current: ${STATUS:-no-response}"
  fi
  sleep 5
done

echo
echo "============================================="
echo "DONE"
echo "Open: http://<EC2-PUBLIC-IP>:${SONAR_PORT}"
echo "Default login: admin / admin (change on first login)"
echo "============================================="
echo
echo "If not UP yet, check:"
echo "sudo systemctl status sonarqube --no-pager -l"
echo "sudo journalctl -u sonarqube -n 200 --no-pager"
echo "tail -n 200 ${SONAR_HOME}/logs/es.log"