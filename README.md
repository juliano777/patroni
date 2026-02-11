# Patroni tutorial

## section


https://www.enterprisedb.com/docs/static/298a2bb5138b10db2c544b54eb6d9256/e1b7c/supported-arch.png


##

[#] 
```bash
cat << EOF > /etc/hosts
127.0.0.1	localhost
127.0.1.1	myhost.patroni.mydomain	myhost

# Patroni cluster ============================================================

# DCS
192.168.56.10  dcs-00.patroni.mydomain      dcs-00
192.168.56.11  dcs-01.patroni.mydomain      dcs-01
192.168.56.12  dcs-02.patroni.mydomain      dcs-02

# Proxy
192.168.56.20  proxy-00.patroni.mydomain    proxy-00
192.168.56.21  proxy-01.patroni.mydomain    proxy-01

# Database
192.168.56.70  db-00.patroni.mydomain       db-00
192.168.56.71  db-01.patroni.mydomain       db-01
192.168.56.72  db-02.patroni.mydomain       db-02

EOF
```