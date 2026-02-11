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

## Comparação geral entre soluções

| Ferramenta | Algoritmo de Consenso | Casos de Uso Principais                 | Observações |
|------------|------------------------|-----------------------------------------|-------------|
| **etcd**   | Raft                   | Configuração distribuída, Kubernetes    | Simples, moderno, focado em key-value com alta consistência |
| **Consul** | Raft                   | Service discovery, KV store, health check | Integração forte com HashiCorp stack (Terraform, Nomad) |
| **ZooKeeper** | Zab (similar a Paxos) | Coordenação de clusters, Hadoop, Kafka | Mais antigo, estável, mas complexo de operar |


👉 Em resumo, um *Distributed Consensus Store* não é feito para guardar grandes volumes de dados, mas sim **pequenas informações críticas com garantias fortes de consistência**.

## ETCD vs Consul (no contexto do Patroni)

Tanto **etcd** quanto **Consul** podem ser usados como *Distributed Configuration Store* pelo Patroni para coordenar **leader election**, **failover** e **estado do cluster PostgreSQL**. Ambos utilizam o algoritmo **Raft**, mas possuem diferenças importantes em foco, ecossistema e operação.

### etcd

**Pontos fortes**
- **Simplicidade e foco**: projetado exclusivamente como um KV store fortemente consistente.
- **Menor complexidade operacional**: menos componentes, menos configurações.
- **Alto desempenho e baixa latência** para operações de consenso.
- **Padrão de fato no ecossistema Kubernetes**, facilitando ambientes cloud-native.
- Integração muito madura e amplamente testada com o Patroni.

**Pontos fracos**
- Não oferece funcionalidades extras como *service discovery* ou *health checks*.
- Ecossistema mais restrito (KV + watch).

**Quando usar etcd com Patroni**
- Clusters PostgreSQL dedicados, onde o DCS serve **apenas** ao Patroni.
- Ambientes Kubernetes ou cloud-native.
- Times que preferem **menos moving parts** e maior previsibilidade.
- Cenários onde simplicidade e estabilidade são prioridade.

---

### Consul

**Pontos fortes**
- **Plataforma multifuncional**: além do KV store, oferece *service discovery*, *health checks* e *service mesh*.
- Forte integração com o **ecossistema HashiCorp** (Terraform, Nomad, Vault).
- Pode centralizar múltiplas necessidades de infraestrutura em uma única ferramenta.
- Boa observabilidade e interface web integrada.

**Pontos fracos**
- **Maior complexidade operacional** quando usado apenas como DCS.
- Overhead maior se o uso for exclusivo para o Patroni.
- Mais superfícies de configuração e dependências.

**Quando usar Consul com Patroni**
- Ambientes que **já utilizam Consul** como padrão organizacional.
- Infraestruturas que se beneficiam de *service discovery* e *health checks* centralizados.
- Cenários onde o PostgreSQL é apenas mais um serviço dentro de uma malha maior.

---

### Comparação direta

| Aspecto | etcd | Consul |
|-------|------|--------|
| Algoritmo de consenso | Raft | Raft |
| Foco principal | KV store consistente | Plataforma de serviços |
| Complexidade operacional | Baixa | Média / Alta |
| Integração com Patroni | Excelente / padrão | Boa |
| Service discovery | Não | Sim |
| Health checks | Não | Sim |
| Kubernetes | Nativo / padrão | Integrável |
| Melhor escolha quando | Simplicidade e foco | Infraestrutura unificada |

👉 **Resumo prático**:  
Para a maioria dos clusters **Patroni + PostgreSQL**, o **etcd é a escolha mais simples, estável e comum**.  
O **Consul** faz mais sentido quando ele **já é parte central da infraestrutura** ou quando suas funcionalidades adicionais trazem valor real além do DCS.