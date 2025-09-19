# Distributed Consensus Store

Um **Distributed Consensus Store** é um sistema de armazenamento distribuído
que garante que múltiplas réplicas de dados cheguem a **acordo consistente**
(_consensus_) sobre o estado do sistema, mesmo diante de falhas de rede ou
servidores.

## Características
- **Consistência forte**: todos os nós veem o mesmo estado após uma decisão.  
- **Alta disponibilidade**: continua operando mesmo com falhas de alguns nós.  
- **Resiliência a falhas**: tolera *crash failures* e *network partitions*.  
- **Algoritmos de consenso**: geralmente baseados em **Raft** ou **Paxos**.  

## Exemplos
- **etcd** – usado pelo Kubernetes para armazenar o estado do cluster.  
- **Consul** – da HashiCorp, voltado para service discovery e configuração.  
- **ZooKeeper** – utilizado em ecossistemas como Hadoop e Kafka.  

## Casos de uso
- **Gerenciamento de configuração distribuída** (ex.: Kubernetes + etcd).  
- **Coordenação de serviços** (ex.: election de líderes, locks distribuídos).  
- **Metadados críticos** (ex.: estado de cluster, membership, endereços de serviços).  

## Comparação entre soluções

| Ferramenta | Algoritmo de Consenso | Casos de Uso Principais                 | Observações |
|------------|------------------------|-----------------------------------------|-------------|
| **etcd**   | Raft                   | Configuração distribuída, Kubernetes    | Simples, moderno, focado em key-value com alta consistência |
| **Consul** | Raft                   | Service discovery, KV store, health check | Integração forte com HashiCorp stack (Terraform, Nomad) |
| **ZooKeeper** | Zab (similar a Paxos) | Coordenação de clusters, Hadoop, Kafka | Mais antigo, estável, mas complexo de operar |


👉 Em resumo, um *Distributed Consensus Store* não é feito para guardar grandes volumes de dados, mas sim **pequenas informações críticas com garantias fortes de consistência**.