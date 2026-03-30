#!/bin/bash
set -e

echo "==> Generating rAthena configuration files from environment variables..."

mkdir -p /rathena/conf/import

# inter_conf.txt - Database connection
cat > /rathena/conf/import/inter_conf.txt <<EOF
sql_connection: {
    id: "${DB_USER}"
    pw: "${DB_PASSWORD}"
    db: "${DB_NAME}"
    host: "${DB_HOST}"
    port: ${DB_PORT}
}
EOF

# login_athena.conf
cat > /rathena/conf/import/login_athena.conf <<EOF
login_server_ip: 0.0.0.0
login_server_port: 6900
new_account: yes
EOF

# char_athena.conf
cat > /rathena/conf/import/char_athena.conf <<EOF
char_server_ip: 0.0.0.0
char_server_port: 6121
login_server_ip: 127.0.0.1
login_server_port: 6900
EOF

# map_athena.conf
cat > /rathena/conf/import/map_athena.conf <<EOF
map_server_ip: 0.0.0.0
char_server_ip: 127.0.0.1
char_server_port: 6121
EOF

# subnet_athena.conf
cat > /rathena/conf/import/subnet_athena.conf <<EOF
subnet: (
  {
    subnet: "0.0.0.0/0"
    char_ip: "${PUBLIC_IP}"
    map_ip: "${PUBLIC_IP}"
  }
)
EOF

echo "==> Configuration files generated."

echo "==> Waiting for database..."
until mariadb-admin ping -h "${DB_HOST}" -u"${DB_USER}" -p"${DB_PASSWORD}" --silent; do
  echo "    Database not ready yet, retrying in 2 seconds..."
  sleep 2
done
echo "==> Database is ready."

echo "==> Checking if database needs initialization..."
if ! mariadb -h "${DB_HOST}" -u"${DB_USER}" -p"${DB_PASSWORD}" "${DB_NAME}" -e "SHOW TABLES LIKE 'login';" | grep -q login; then
  echo "==> Running main.sql..."
  mariadb -h "${DB_HOST}" -u"${DB_USER}" -p"${DB_PASSWORD}" "${DB_NAME}" < /rathena/sql-files/main.sql
  if [ -f /rathena/sql-files/logs.sql ]; then
    echo "==> Running logs.sql..."
    mariadb -h "${DB_HOST}" -u"${DB_USER}" -p"${DB_PASSWORD}" "${DB_NAME}" < /rathena/sql-files/logs.sql
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

# Wait for any process to exit
wait -n
echo "==> A server process has exited. Shutting down."
