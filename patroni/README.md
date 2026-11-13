# Patroni

```bash
sudo apt install -y patroni
```

```bash
patroni --version
```

```bash
sudo apt install -y etcd-client
```

```bash
sudo scp -O dcs-00:/etc/dcs/cert/ca.crt /etc/patroni/etcd-ca.crt

sudo chgrp -R postgres /etc/patroni

sudo chmod 770 /etc/patroni
```

db-0[0-2]
```bash
T=`mktemp -d`

openssl req -new -newkey rsa:4096 -noenc \
  -keyout /etc/patroni/etcd-client.key \
  -out $T/`hostname -s`-client.csr \
  -subj "/CN=`hostname -s`"

scp -O $T/`hostname -s`-client.csr dcs-00:/tmp/

rm -rf $T
```

dcs-00
```bash
cd /etc/dcs/cert

cat > client.ext <<'EOF'
basicConstraints=CA:FALSE
keyUsage=digitalSignature,keyEncipherment
extendedKeyUsage=clientAuth
EOF

openssl x509 -req -in /tmp/db-00-client.csr \
  -CA ca.crt -CAkey ca.key -CAserial ca.srl \
  -out /tmp/db-00-client.crt -days 825 -sha256 \
  -extfile client.ext

scp -O /tmp/db-00-client.crt db-00:/etc/patroni/etcd-client.crt

rm  /tmp/db-00-client.csr /tmp/db-00-client.crt
```






```bash
export ETCDCTL_CACERT='/etc/patroni/etcd-ca.crt'
export ETCDCTL_CERT='/etc/patroni/etcd-client.crt'
export ETCDCTL_KEY='/etc/patroni/etcd-client.key'

ETCDCTL_ENDPOINTS='https://dcs-00.patroni.mydomain:2379,'
ETCDCTL_ENDPOINTS+='https://dcs-01.patroni.mydomain:2379,'
ETCDCTL_ENDPOINTS+='https://dcs-02.patroni.mydomain:2379'

export ETCDCTL_ENDPOINTS

etcdctl endpoint health --user root
```


```bash
E='etcdctl --user root'

$E role add patroni
$E role grant-permission patroni --prefix=true readwrite /service/
$E user add patroni              # pede a senha duas vezes
$E user grant-role patroni patroni
```

```
[postgres@db-00 ~]$ etcdctl --user root role get patroni
Password: 
Role patroni
KV Read:
	[/service/, /service0) (prefix /service/)
KV Write:
	[/service/, /service0) (prefix /service/)
[postgres@db-00 ~]$ etcdctl --user root user get patroni
Password: 
User: patroni
Roles: patroni
```

```
[postgres@db-00 ~]$ etcdctl --user patroni put /service/test ok
Password: 
OK
[postgres@db-00 ~]$ etcdctl --user patroni get /service/test
Password: 
/service/test
ok
[postgres@db-00 ~]$ etcdctl --user patroni del /service/test
Password: 
1
[postgres@db-00 ~]$ etcdctl --user patroni put /other-key x
Password: 
{"level":"warn","ts":"2026-11-13T18:28:36.255514-0300","logger":"etcd-client","caller":"v3/retry_interceptor.go:63","msg":"retrying of unary invoker failed","target":"etcd-endpoints://0xc0003a8b40/dcs-00.patroni.mydomain:2379","attempt":0,"error":"rpc error: code = PermissionDenied desc = etcdserver: permission denied"}
Error: etcdserver: permission denied
```


Em cada nó:
```bash
sudo vim /etc/patroni/dcs.yml
```
```yaml
etcd3:
  hosts:
    - dcs-00.patroni.mydomain:2379
    - dcs-01.patroni.mydomain:2379
    - dcs-02.patroni.mydomain:2379
  protocol: https
  cacert: /etc/patroni/etcd-ca.crt
  cert: /etc/patroni/etcd-client.crt
  key: /etc/patroni/etcd-client.key
  username: patroni
  password: "123"
```

```bash
sudo chown root:postgres /etc/patroni/dcs.yml
sudo chmod 640 /etc/patroni/dcs.yml
```

```bash
sudo vim /etc/patroni/18-main.yml
```
```yaml
scope: "18-main"
namespace: "/postgresql-common/"

bootstrap:
  dcs:
    postgresql:
      use_pg_rewind: false
      use_slots: false
      remove_data_directory_on_rewind_failure: false
      remove_data_directory_on_diverged_timelines: false
```

```bash
sudo chown postgres:postgres /etc/patroni/18-main.yml
sudo chmod 600 /etc/patroni/18-main.yml
```

```bash
sudo -u postgres patroni \
  --validate-config -i /etc/patroni/18-main.yml
```

```bash
sudo -u postgres psql -c \
  "SELECT system_identifier FROM pg_control_system();"
```




