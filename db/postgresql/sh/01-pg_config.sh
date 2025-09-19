#!/bin/bash

export PGMAJOR='17'
export PGDATA="/var/lib/postgresql/${PGMAJOR}/main"
export PGCONFDIR="/etc/postgresql/${PGMAJOR}/main"
export PGBIN="/usr/lib/postgresql/${PGMAJOR}/bin"
export PGLOG='/var/log/postgresql'

#
initdb -E utf8 -k 



# PostgreSQL configuration
sed "s:\(^#listen_addresses.*\):\1\nlisten_addresses = '*':g" \
-i ${PGDATA}/postgresql.conf

sed "s:\(^#log_destination.*\):\1\nlog_destination = 'stderr':g" \
-i ${PGDATA}/postgresql.conf

sed "s:\(^#logging_collector.*\):\1\nlogging_collector = on:g" \
-i ${PGDATA}/postgresql.conf

sed "s:\(^#\)\(log_filename.*\):\1\2\n\2:g" \
-i ${PGDATA}/postgresql.conf

sed "s:\(^#log_directory.*\):\1\nlog_directory = '${PGLOG}':g" \
-i ${PGDATA}/postgresql.conf


#
pg_ctl start
