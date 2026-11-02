#!/usr/bin/env bash
#
# start.sh - sobe o laboratório etcd (3 nós) com Vagrant + Ansible.
#
# Uso:
#   ./start.sh [up|provision|status|ssh|destroy|help]
#
#   up         (padrão) valida pré-requisitos, cria as VMs e configura o cluster
#   provision  reaplica somente o Ansible nas VMs já existentes
#   status     mostra as VMs e o estado do cluster etcd
#   ssh [vm]   abre um shell na VM (padrão: dcs-00)
#   destroy    apaga as VMs do laboratório (a box permanece)
#
# Variáveis opcionais:
#   BOX_FILE   caminho de um arquivo .box a registrar caso a box ainda não exista
#              Ex.: BOX_FILE=~/boxes/debian13.box ./start.sh

set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

BOX_NAME='localboxes/debian13'
COLLECTIONS_DIR='ansible/collections'
FIRST_NODE='dcs-00'

log() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
die() { printf '\033[1;31mErro:\033[0m %s\n' "$*" >&2; exit 1; }

need() {
  command -v "$1" > /dev/null 2>&1 || die "'$1' não encontrado. $2"
}

# ---------------------------------------------------------------------------
check_requirements() {
  need vagrant 'Instale o Vagrant: https://developer.hashicorp.com/vagrant/install'
  need VBoxManage 'Instale o VirtualBox.'
  ensure_ansible
  ensure_collections
  ensure_box
}

# Usa o Ansible do sistema; se não houver, cria um virtualenv local (.venv)
ensure_ansible() {
  if [[ -x .venv/bin/ansible-playbook ]]; then
    export PATH="${PWD}/.venv/bin:${PATH}"
  fi

  if command -v ansible-playbook > /dev/null 2>&1; then
    return
  fi

  log 'Ansible não encontrado: criando um virtualenv em .venv'
  need python3 'Instale o Python 3 (e o pacote python3-venv no Debian/Ubuntu).'
  python3 -m venv .venv \
    || die "Falha ao criar o virtualenv. No Debian/Ubuntu: sudo apt install python3-venv"
  .venv/bin/pip install --quiet --upgrade pip ansible-core
  export PATH="${PWD}/.venv/bin:${PATH}"
}

ensure_collections() {
  if [[ -d "${COLLECTIONS_DIR}/ansible_collections/community/crypto" ]]; then
    return
  fi

  log 'Instalando as collections do Ansible (community.crypto)'
  ansible-galaxy collection install \
    -r ansible/requirements.yml \
    -p "${COLLECTIONS_DIR}"
}

ensure_box() {
  if vagrant box list 2> /dev/null | grep -q "^${BOX_NAME} .*virtualbox"; then
    return
  fi

  if [[ -n "${BOX_FILE:-}" ]]; then
    [[ -f "${BOX_FILE}" ]] || die "BOX_FILE='${BOX_FILE}' não existe."
    log "Registrando a box ${BOX_NAME} a partir de ${BOX_FILE}"
    vagrant box add --name "${BOX_NAME}" "${BOX_FILE}"
    return
  fi

  cat >&2 << EOF
Erro: a box '${BOX_NAME}' não está registrada no Vagrant.

Gere o arquivo .box a partir da sua VM (desligada) e registre-o:

  vagrant package --base "<nome-da-vm-debian13>" --output debian13.box
  BOX_FILE=./debian13.box ./start.sh

(ou, manualmente: vagrant box add --name ${BOX_NAME} debian13.box)
EOF
  exit 1
}

# ---------------------------------------------------------------------------
cluster_status() {
  vagrant ssh "${FIRST_NODE}" -c \
    '. ~/.etcdvars && etcdctl endpoint status --write-out=table && etcdctl endpoint health --write-out=table'
}

cmd_up() {
  check_requirements
  log 'Criando as VMs e configurando o cluster (vagrant up)'
  vagrant up --provider virtualbox
  log 'Estado do cluster etcd'
  cluster_status || log "Não foi possível consultar o cluster; tente: ./start.sh provision"
  log "Pronto. Acesse com: ./start.sh ssh   (etcdctl já configurado)"
}

cmd_provision() {
  check_requirements
  log 'Reaplicando o Ansible (vagrant provision)'
  vagrant provision
  cluster_status || true
}

cmd_status() {
  need vagrant 'Instale o Vagrant.'
  vagrant status
  cluster_status || true
}

cmd_ssh() {
  need vagrant 'Instale o Vagrant.'
  vagrant ssh "${1:-${FIRST_NODE}}"
}

cmd_destroy() {
  need vagrant 'Instale o Vagrant.'
  log 'Destruindo as VMs do laboratório'
  vagrant destroy -f
}

usage() {
  sed -n '3,17p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

case "${1:-up}" in
  up)        cmd_up ;;
  provision) cmd_provision ;;
  status)    cmd_status ;;
  ssh)       shift; cmd_ssh "$@" ;;
  destroy)   cmd_destroy ;;
  help|-h|--help) usage ;;
  *)         usage; exit 1 ;;
esac
