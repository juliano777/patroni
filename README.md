# Patroni tutorial

## Sobre

Este repositório tem por fim de forma didática, com teoria e prática servir
de tutorial de implementação de clusters Patroni em diferentes cenários.

## Laboratórios

![Tux](img/tux.png)

Visando abranger simulações de ambientes corporativos, todas máquinas
participantes dos ambientes a serem simulados serão Linux.  
E justamente pensando em ambientes corporativos, a parte prática poderá ser
feita utilizando tanto distros Linux baseadas em Debian ou Red Hat.

[#] Criação de /etc/hosts na máquina template:
```bash
cat << EOF > /etc/hosts
127.0.0.1	localhost
127.0.1.1	myhost.patroni.mydomain	myhost

# Patroni cluster ============================================================

# Template
192.168.56.254  template.patroni.mydomain      template

# DCS
192.168.56.10   dcs-00.patroni.mydomain      dcs-00
192.168.56.11   dcs-01.patroni.mydomain      dcs-01
192.168.56.12   dcs-02.patroni.mydomain      dcs-02

# Proxy
192.168.56.20   proxy-00.patroni.mydomain    proxy-00
192.168.56.21   proxy-01.patroni.mydomain    proxy-01

# Database
192.168.56.70   db-00.patroni.mydomain       db-00
192.168.56.71   db-01.patroni.mydomain       db-01
192.168.56.72   db-02.patroni.mydomain       db-02
192.168.56.73   db-03.patroni.mydomain       db-03

# App
192.168.56.100  app-00.patroni.mydomain      app-00
EOF
```
