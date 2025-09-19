#!/bin/bash

# Environment variables
export PGMAJOR='17'
export PGDATA="/var/lib/postgresql/${PGMAJOR}/main"
export PGCONFDIR="/etc/postgresql/${PGMAJOR}/main"
export PGBIN="/usr/lib/postgresql/${PGMAJOR}/bin"
export PGLOG='/var/log/postgresql'

# Update repo packages
sudo apt update

# Installation of packages
sudo apt install -y postgresql-common curl ca-certificates

# Automated repository configuration: 
sudo /usr/share/postgresql-common/pgdg/apt.postgresql.org.sh -y

# PostgreSQL installation
sudo apt -y install postgresql-${PGMAJOR} 

# Stop PostgreSQL service
sudo systemctl stop postgresql

#
mv ${PGCONFDIR}/ ${PGDATA}/

# 
ls -1 ${PGDATA}/{*.conf,conf.d,environment} | \
tr -d ':' | xargs -i ln -sf {} ${PGCONFDIR}/

#
rm -fr ${PGDATA}

#
cat << EOF >> ~postgres/.bashrc

export export PGMAJOR='${PGMAJOR}'
export PGBIN="/usr/lib/postgresql/\${PGMAJOR}/bin"
export PGDATA="/var/lib/postgresql/\${PGMAJOR}/main"
export PATH="\${PATH}:\${PGBIN}"

EOF

# 
cat << EOF > ~postgres/.psqlrc
\set COMP_KEYWORD_CASE upper
\set HISTCONTROL ignoreboth
\x auto

EOF

#
chown -R postgres: ~postgres/
