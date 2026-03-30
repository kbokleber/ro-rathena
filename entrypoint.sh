#!/bin/bash
set -e

echo "==> Patching rAthena configuration files with environment variables..."

# Patch inter_athena.conf - sets the DB connection for all servers
# This file controls login, char, map and log database connections
INTER_CONF="/rathena/conf/inter_athena.conf"

# Replace all DB host references (127.0.0.1 -> DB_HOST)
sed -i "s|^\(login_server_ip:\s*\).*|\1${DB_HOST}|g" "$INTER_CONF"
sed -i "s|^\(char_server_ip:\s*\).*|\1${DB_HOST}|g"  "$INTER_CONF"
sed -i "s|^\(map_server_ip:\s*\).*|\1${DB_HOST}|g"   "$INTER_CONF"
sed -i "s|^\(log_db_ip:\s*\).*|\1${DB_HOST}|g"       "$INTER_CONF"

# Replace DB ports
sed -i "s|^\(login_server_port:\s*\).*|\1${DB_PORT}|g" "$INTER_CONF"
sed -i "s|^\(char_server_port:\s*\).*|\1${DB_PORT}|g"  "$INTER_CONF"
sed -i "s|^\(map_server_port:\s*\).*|\1${DB_PORT}|g"   "$INTER_CONF"
sed -i "s|^\(log_db_port:\s*\).*|\1${DB_PORT}|g"       "$INTER_CONF"

# Replace DB username
sed -i "s|^\(login_server_id:\s*\).*|\1${DB_USER}|g" "$INTER_CONF"
sed -i "s|^\(char_server_id:\s*\).*|\1${DB_USER}|g"  "$INTER_CONF"
sed -i "s|^\(map_server_id:\s*\).*|\1${DB_USER}|g"   "$INTER_CONF"
sed -i "s|^\(log_db_id:\s*\).*|\1${DB_USER}|g"       "$INTER_CONF"

# Replace DB password
sed -i "s|^\(login_server_pw:\s*\).*|\1${DB_PASSWORD}|g" "$INTER_CONF"
sed -i "s|^\(char_server_pw:\s*\).*|\1${DB_PASSWORD}|g"  "$INTER_CONF"
sed -i "s|^\(map_server_pw:\s*\).*|\1${DB_PASSWORD}|g"   "$INTER_CONF"
sed -i "s|^\(log_db_pw:\s*\).*|\1${DB_PASSWORD}|g"       "$INTER_CONF"

# Replace DB name
sed -i "s|^\(login_server_db:\s*\).*|\1${DB_NAME}|g" "$INTER_CONF"
sed -i "s|^\(char_server_db:\s*\).*|\1${DB_NAME}|g"  "$INTER_CONF"
sed -i "s|^\(map_server_db:\s*\).*|\1${DB_NAME}|g"   "$INTER_CONF"
sed -i "s|^\(log_db_db:\s*\).*|\1${DB_NAME}|g"       "$INTER_CONF"

# Patch subnet_athena.conf - sets PUBLIC_IP for client connections
SUBNET_CONF="/rathena/conf/subnet_athena.conf"
sed -i "s|char_ip:.*|char_ip: ${PUBLIC_IP}|g" "$SUBNET_CONF"
sed -i "s|map_ip:.*|map_ip: ${PUBLIC_IP}|g"   "$SUBNET_CONF"

echo "==> Configuration patched successfully."
echo "==> DB Host: ${DB_HOST}, DB Name: ${DB_NAME}, Public IP: ${PUBLIC_IP}"

echo "==> Waiting for database at ${DB_HOST}:${DB_PORT}..."
until mariadb-admin ping -h "${DB_HOST}" -P "${DB_PORT}" -u"${DB_USER}" -p"${DB_PASSWORD}" --silent 2>/dev/null; do
  echo "    Database not ready yet, retrying in 2 seconds..."
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
