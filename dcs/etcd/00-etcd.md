# etcd

O **etcd** é um banco de dados chave-valor distribuído e altamente consistente, 
desenvolvido pela CoreOS (atualmente mantido pela CNCF - Cloud Native Computing Foundation).  
Ele é projetado para fornecer **armazenamento confiável e consistente de pequenas quantidades de dados críticos** em sistemas distribuídos.

## Características principais
- **Consistência forte**: utiliza o algoritmo de consenso **Raft**.  
- **Armazenamento chave-valor**: simples e direto.  
- **Alta disponibilidade**: suporta clusters com múltiplos nós.  
- **Resiliência a falhas**: continua operando mesmo com a queda de alguns nós.  
- **API gRPC/HTTP**: fornece uma interface simples para operações de leitura e escrita.  

## Principais usos
- **Kubernetes**: usado como *data store* para todo o estado do cluster.  
- **Service discovery**: aplicações podem registrar e consultar serviços disponíveis.  
- **Configuração distribuída**: garante que várias instâncias de uma aplicação leiam sempre o mesmo valor atualizado.  
- **Coordenação de sistemas**: permite implementar *leader election* e *distributed locking*.  

## Arquitetura
- Um cluster do etcd é composto por **3 a 5 nós** (recomendado para alta disponibilidade).  
- As escritas são aplicadas apenas após atingir **maioria (quorum)**.  
- A replicação segue o algoritmo Raft, garantindo consistência entre réplicas.  

## Vantagens
- Simples de configurar e operar.  
- Excelente integração com **Kubernetes**.  
- Projetado para **baixa latência** e **consistência forte**.  

## Desvantagens
- Não é adequado para armazenar grandes volumes de dados.  
- Exige atenção na configuração de rede e quorum para evitar indisponibilidade.  

---
👉 Em resumo, o **etcd** é a base de confiança de sistemas distribuídos modernos, 
fornecendo armazenamento consistente para informações críticas como configurações, 
estado de cluster e metadados.
