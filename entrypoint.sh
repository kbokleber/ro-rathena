#!/bin/bash
set -e

echo "==> Configuring rAthena database settings from environment variables..."

mkdir -p /rathena/conf/import

cat > /rathena/conf/import/inter_conf.txt <<EOF
// Login DB
login_server_ip: ${DB_HOST}
login_server_port: ${DB_PORT}
login_server_id: ${DB_USER}
login_server_pw: ${DB_PASSWORD}
login_server_db: ${DB_NAME}

// IP Ban DB (Was causing the 127.0.0.1 error on ipban.cpp)
ipban_db_ip: ${DB_HOST}
ipban_db_port: ${DB_PORT}
ipban_db_id: ${DB_USER}
ipban_db_pw: ${DB_PASSWORD}
ipban_db_db: ${DB_NAME}

// Char DB
char_server_ip: ${DB_HOST}
char_server_port: ${DB_PORT}
char_server_id: ${DB_USER}
char_server_pw: ${DB_PASSWORD}
char_server_db: ${DB_NAME}

// Map DB
map_server_ip: ${DB_HOST}
map_server_port: ${DB_PORT}
map_server_id: ${DB_USER}
map_server_pw: ${DB_PASSWORD}
map_server_db: ${DB_NAME}

// Web DB
web_server_ip: ${DB_HOST}
web_server_port: ${DB_PORT}
web_server_id: ${DB_USER}
web_server_pw: ${DB_PASSWORD}
web_server_db: ${DB_NAME}

// Log DB
log_db_ip: ${DB_HOST}
log_db_port: ${DB_PORT}
log_db_id: ${DB_USER}
log_db_pw: ${DB_PASSWORD}
log_db_db: ${DB_NAME}
EOF

cat > /rathena/conf/import/char_conf.txt <<EOF
login_server_ip: db
login_server_port: 6900
char_ip: ${PUBLIC_IP}
EOF

cat > /rathena/conf/import/map_conf.txt <<EOF
char_server_ip: db
char_server_port: 6121
map_ip: ${PUBLIC_IP}
EOF

cat > /rathena/conf/import/subnet_conf.txt <<EOF
subnet: (
  {
    subnet: "0.0.0.0/0"
    char_ip: "${PUBLIC_IP}"
    map_ip: "${PUBLIC_IP}"
  }
)
EOF

# Optional fallback for YAML based setups in newer rAthena versions
SQL_YML="/rathena/conf/global/sql_connection.yml"
if [ -f "$SQL_YML" ]; then
  sed -i "s|Host:.*|Host: ${DB_HOST}|g"            "$SQL_YML"
  sed -i "s|Port:.*|Port: ${DB_PORT}|g"             "$SQL_YML"
  sed -i "s|Username:.*|Username: ${DB_USER}|g"   "$SQL_YML"
  sed -i "s|Password:.*|Password: ${DB_PASSWORD}|g" "$SQL_YML"
  sed -i "s|Database:.*|Database: ${DB_NAME}|g"     "$SQL_YML"
fi

# To make extra sure, global replace 127.0.0.1 to db in all main confs
find /rathena/conf/ -maxdepth 1 -name "*_athena.conf" -exec sed -i "s/127\.0\.0\.1/${DB_HOST}/g" {} +

echo "==> Configurations generated successfully."
echo "==> Values set: Host=${DB_HOST}, Port=${DB_PORT}, DB=${DB_NAME}, PublicIP=${PUBLIC_IP}"

echo "==> Waiting for database at ${DB_HOST}:${DB_PORT}..."
until mariadb-admin ping -h "${DB_HOST}" -P "${DB_PORT}" -u"${DB_USER}" -p"${DB_PASSWORD}" --silent 2>/dev/null; do
  echo "    Database not ready, retrying in 2s..."
  sleep 2
done
echo "==> Database is ready."

echo "==> Checking if database needs initialization..."
if ! mariadb -h "${DB_HOST}" -P "${DB_PORT}" -u"${DB_USER}" -p"${DB_PASSWORD}" "${DB_NAME}" -e "SHOW TABLES LIKE 'login';" 2>/dev/null | grep -q 'login'; then
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
