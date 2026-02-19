#!/bin/bash

sudo systemctl stop etcd 

sudo rm -fr /etc/dcs /var/lib/dcs

sed -i '/# Read etcd environment variables file/d' ~/.bashrc
sed -i '\|source ~/.etcdvars|d' ~/.bashrc
sed -i '${/^$/d;}' ~/.bashrc

sudo apt purge -y etcd-server
