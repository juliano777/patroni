# HAProxy

```bash
# Debian
sudo apt install -y haproxy

# Red Hat
sudo dnf install -y haproxy
```


```bash
sudo cp /etc/haproxy/haproxy.cfg /etc/haproxy/haproxy.cfg.bak
```

```bash
sudo vim /etc/haproxy/haproxy.cfg
```

```config
global
    maxconn 1000

defaults
    mode tcp
    timeout connect 5s
    timeout client 1m
    timeout server 1m

# PostgreSQL - Leitura e escrita
listen postgresql_write
    bind *:5000
    option httpchk GET /primary
    http-check expect status 200

    server db-00 192.168.56.70:5432 check port 8008
    server db-01 192.168.56.71:5432 check port 8008
    server db-02 192.168.56.72:5432 check port 8008

# PostgreSQL - Somente leitura
listen postgresql_read
    bind *:5001
    balance roundrobin
    option httpchk GET /replica
    http-check expect status 200

    server db-00 192.168.56.70:5432 check port 8008
    server db-01 192.168.56.71:5432 check port 8008
    server db-02 192.168.56.72:5432 check port 8008
```

```bash
/usr/sbin/haproxy -c -f /etc/haproxy/haproxy.cfg
```

```bash
sudo systemctl enable --now haproxy
```

Conexão com o primário:
```bash
psql -h proxy-00 -p 5000 -U postgres
```


Conexão com um dos standbys:
```bash
psql -h proxy-00 -p 5001 -U postgres
```

Para verificar o papel do servidor:
```sql
SELECT inet_server_addr(), pg_is_in_recovery();
```

