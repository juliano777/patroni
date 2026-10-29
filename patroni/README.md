# Patroni

```bash
sudo apt install -y patroni
```

```bash
patroni --version
```

Em cada nó:
```bash
sudo vim /etc/patroni/dcs.yml
```
```yaml
etcd3:
  hosts:
    - 192.168.56.10:2379
    - 192.168.56.11:2379
    - 192.168.56.12:2379
  protocol: http
  username: "USUARIO_ETCD"
  password: "SUBSTITUIR_SENHA"
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




