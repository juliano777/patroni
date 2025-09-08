

Create a Vagrantfile
```bash
vim Vagrantfile.etcd
```
```ruby
Vagrant.configure("2") do |config|
  config.vm.define "etcd" do |etcd|
    etcd.vm.box = "debian/bullseye64"

    # Hostname
    etcd.vm.hostname = "etcd.mydomain.test"

    # Private IP
    etcd.vm.network "private_network", ip: "192.168.56.10"

    # Resources settings
    etcd.vm.provider "virtualbox" do |vb|
      vb.name = "etcd-mydomain-test"
      vb.memory = 1024
      vb.cpus = 2
    end
  end
end
```

Create the VM
```bash
VAGRANT_VAGRANTFILE=Vagrantfile.etcd vagrant up
```

VAGRANT_VAGRANTFILE=Vagrantfile.etcd vagrant ssh etcd





```bash

sudo apt update
sudo apt install -y etcd-client etcd-server

sudo netstat -nltp | grep etcd
tcp        0      0 127.0.0.1:2379          0.0.0.0:*               LISTEN      373/etcd            
tcp        0      0 127.0.0.1:2380          0.0.0.0:*               LISTEN      373/etcd

sudo mkdir /etc/etcd

sudo sh -c 'cat << EOF > /etc/etcd/etcd.yaml
listen-client-urls: "http://192.168.56.10:2379"
listen-peer-urls: "http://192.168.56.10:2380"
EOF'
```








