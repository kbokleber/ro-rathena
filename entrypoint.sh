#!/bin/bash
set -e

echo "==> Patching rAthena configuration files with environment variables..."
echo "==> DB_HOST=${DB_HOST} DB_PORT=${DB_PORT} DB_NAME=${DB_NAME} DB_USER=${DB_USER} PUBLIC_IP=${PUBLIC_IP}"

INTER_CONF="/rathena/conf/inter_athena.conf"

echo "==> DEBUG: Lines with 'server_ip' or 'host' in inter_athena.conf:"
grep -n "server_ip\|log_db_ip\|host:" "$INTER_CONF" | head -30 || echo "(no matches)"

echo "==> DEBUG: First 5 lines of inter_athena.conf:"
head -5 "$INTER_CONF"

# Patch inter_athena.conf - old key:value format
sed -i "s|^\(login_server_ip:\s*\).*|\1${DB_HOST}|g"  "$INTER_CONF"
sed -i "s|^\(char_server_ip:\s*\).*|\1${DB_HOST}|g"   "$INTER_CONF"
sed -i "s|^\(map_server_ip:\s*\).*|\1${DB_HOST}|g"    "$INTER_CONF"
sed -i "s|^\(log_db_ip:\s*\).*|\1${DB_HOST}|g"        "$INTER_CONF"

sed -i "s|^\(login_server_port:\s*\).*|\1${DB_PORT}|g" "$INTER_CONF"
sed -i "s|^\(char_server_port:\s*\).*|\1${DB_PORT}|g"  "$INTER_CONF"
sed -i "s|^\(map_server_port:\s*\).*|\1${DB_PORT}|g"   "$INTER_CONF"
sed -i "s|^\(log_db_port:\s*\).*|\1${DB_PORT}|g"       "$INTER_CONF"

sed -i "s|^\(login_server_id:\s*\).*|\1${DB_USER}|g"  "$INTER_CONF"
sed -i "s|^\(char_server_id:\s*\).*|\1${DB_USER}|g"   "$INTER_CONF"
sed -i "s|^\(map_server_id:\s*\).*|\1${DB_USER}|g"    "$INTER_CONF"
sed -i "s|^\(log_db_id:\s*\).*|\1${DB_USER}|g"        "$INTER_CONF"

sed -i "s|^\(login_server_pw:\s*\).*|\1${DB_PASSWORD}|g" "$INTER_CONF"
sed -i "s|^\(char_server_pw:\s*\).*|\1${DB_PASSWORD}|g"  "$INTER_CONF"
sed -i "s|^\(map_server_pw:\s*\).*|\1${DB_PASSWORD}|g"   "$INTER_CONF"
sed -i "s|^\(log_db_pw:\s*\).*|\1${DB_PASSWORD}|g"       "$INTER_CONF"

sed -i "s|^\(login_server_db:\s*\).*|\1${DB_NAME}|g"  "$INTER_CONF"
sed -i "s|^\(char_server_db:\s*\).*|\1${DB_NAME}|g"   "$INTER_CONF"
sed -i "s|^\(map_server_db:\s*\).*|\1${DB_NAME}|g"    "$INTER_CONF"
sed -i "s|^\(log_db_db:\s*\).*|\1${DB_NAME}|g"        "$INTER_CONF"

# Also create import override with correct key:value format
mkdir -p /rathena/conf/import
cat > /rathena/conf/import/inter_conf.txt <<EOF
// MySQL Login server
login_server_ip: ${DB_HOST}
login_server_port: ${DB_PORT}
login_server_id: ${DB_USER}
login_server_pw: ${DB_PASSWORD}
login_server_db: ${DB_NAME}

// MySQL Character server
char_server_ip: ${DB_HOST}
char_server_port: ${DB_PORT}
char_server_id: ${DB_USER}
char_server_pw: ${DB_PASSWORD}
char_server_db: ${DB_NAME}

// MySQL Map server
map_server_ip: ${DB_HOST}
map_server_port: ${DB_PORT}
map_server_id: ${DB_USER}
map_server_pw: ${DB_PASSWORD}
map_server_db: ${DB_NAME}

// MySQL Log DB
log_db_ip: ${DB_HOST}
log_db_port: ${DB_PORT}
log_db_id: ${DB_USER}
log_db_pw: ${DB_PASSWORD}
log_db_db: ${DB_NAME}
EOF

# Patch YAML-based sql_connection if it exists
SQL_YML="/rathena/conf/global/sql_connection.yml"
if [ -f "$SQL_YML" ]; then
  echo "==> DEBUG: Found YAML sql_connection config:"
  cat "$SQL_YML"
  sed -i "s|Host:.*|Host: ${DB_HOST}|g"            "$SQL_YML"
  sed -i "s|Port:.*|Port: ${DB_PORT}|g"             "$SQL_YML"
  sed -i "s|Username:.*|Username: ${DB_USER}|g"     "$SQL_YML"
  sed -i "s|Password:.*|Password: ${DB_PASSWORD}|g" "$SQL_YML"
  sed -i "s|Database:.*|Database: ${DB_NAME}|g"     "$SQL_YML"
else
  echo "==> DEBUG: No YAML sql_connection config found"
fi

# Patch subnet_athena.conf for PUBLIC_IP
SUBNET_CONF="/rathena/conf/subnet_athena.conf"
sed -i "s|char_ip:.*|char_ip: ${PUBLIC_IP}|g" "$SUBNET_CONF"
sed -i "s|map_ip:.*|map_ip: ${PUBLIC_IP}|g"   "$SUBNET_CONF"

echo "==> DEBUG: After patch - login_server_ip line:"
grep "login_server_ip" "$INTER_CONF" || echo "(not found in inter_athena.conf)"

echo "==> Waiting for database at ${DB_HOST}:${DB_PORT}..."
until mariadb-admin ping -h "${DB_HOST}" -P "${DB_PORT}" -u"${DB_USER}" -p"${DB_PASSWORD}" --silent 2>/dev/null; do
  echo "    Database not ready, retrying in 2s..."
  sleep 2
done
echo "==> Database is ready."

echo "==> Checking if database needs initialization..."
if ! mariadb -h "${DB_HOST}" -P "${DB_PORT}" -u"${DB_USER}" -p"${DB_PASSWORD}" "${DB_NAME}" -e "SHOW TABLES LIKE 'login';" 2>/dev/null | grep -q login; then
  echo "==> Running main.sql..."
  mariadb -h "${DB_HOST}" -P "${DB_PORT}" -u"${DB_USER}" -p"${DB_PASSWORD}" "${DB_NAME}" < /rathena/sql-files/main.sql
  if [ -f /rathena/sql-files/logs.sql ]; then
    echo "==> Running logs.sql..."
    mariadb -h "${DB_HOST}" -P "${DB_PORT}" -u"${DB_USER}" -p"${DB_PASSWORD}" "${DB_NAME}" < /rathena/sql-files/logs.sql
  fi
  echo "==> Database initialized."
else
  echo "==> Database already initialized, skipping."
fi

echo "==> Starting rAthena servers..."
cd /rathena
./login-server &
./char-server &
./map-server &

wait -n
echo "==> A server process has exited. Shutting down."
