# KSHA
Simple Kubernetes Shell Script Autoscaler

O KSHA (Kubernetes Shell Script Autoscaler) é uma prova de conceito para autoscaling baseado em métricas ("event-driven") para kubernetes, o controlador foi desenvolvido em shell script com base no princípio KISS e a idéia principal é escalar containers no Kubernetes com maior simplicidade possível.

![ksha](https://user-images.githubusercontent.com/4332906/113611302-b388ad00-9624-11eb-8131-190c83cdf7ae.png)

*O controlador é baseado em três sessões:*

**Coleta das métricas**

A coleta das métricas é feita por scripts pertecentes ao diretório `metrics.d` na raiz do projeto, os scripts customizados tem como objetivo somente retornar uma métrica com valor inteiro para o script `controller.sh`, as métricas podem ser coletadas de qualquer origem desde que a imagem possua os recursos necessários.

O exemplo atual utiliza o cloudwatch como origem das métricas e por este motivo é utilizado a imagem aws-cli pois a mesma já contém as ferramentas necessárias para extrair as métricas através do comando `aws`. Outras métricas padrões vão ser adicionadas ao projeto futuramente, porém é possível customizar métricas conforme suas necessidades com shell script adicionando novos scripts ao diretório `metrics.d`.

Caso deseje colaborar com o projeto é só nos enviar um PR com o seu script customizado :)


**Análise das métricas**

A análise das métricas é feitas através do script `controller.sh` durante a sua inicialização dentro do POD o script recebe as condições através da variável de ambiente CONDITIONS, está variável é uma lista com as condições e no atual momento do projeto é somente possível definir a quantidade mínima de PODs para um valor X de métrica, por exemplo:
> CONDITIONS="0=1 1000=2 2000=3 3000=4 4100=5 9000=10"

*As condições devem ser separadas por espaços e sempre utilizar a seguinte sintaxe* `VALOR_MINIMO=QUANTIDADE_DE_PODS`.


**Ação sobre a métrica**

A condição quando acionada dispara um ação na API do Kubernetes via `curl` atualizando a quantidade mínima de PODs para o deployment na namespace especificada através das variáveis de ambientes `NAMESPACE` e `DEPLOYMENT`.

Futuramente será adicionado um *override* para a chamada da API desta forma deixando o controlador mais modular para demais versões e ações do kubernentes.


## Instalando KSHA no Kubernentes
Atualmente estamos disponibilizando a versão BETA da imagem do controlador em nosso repositório do Docker Hub: `krenek/ksha:latest`

Na raiz deste repositório GIT contém um exemplo de deployment (`deployment.yaml`) utilizado para aplicar a instalação do KSHA no Kubernetes, abaixo uma breve descrição de cada sessão deste arquivo YAML:

**ServiceAccount**

```
apiVersion: v1
kind: ServiceAccount
metadata:
  name: ksha-controller
```

É necessário criar uma ServiceAccount para que possamos atribuir as permissões do POD a ServiceAccount criada no Kubernetes.

**ClusterRole**
```
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRole
metadata:
  name: cr-ksha-controller
rules:
- apiGroups: ["apps"]
  resources:
    - "deployments"
  verbs: ["patch"]
```

A ClusterRole é a regra com as permissões para qual vamos associar a ServiceAccount criada, neste caso estamos dando permissão para aplicar `patch` na resource `deployments` da apiGroup `apps`.

**ClusterRoleBinding**

```
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRoleBinding
metadata:
  name: crb-ksha-controller
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cr-ksha-controller
subjects:
- kind: ServiceAccount
  name: ksha-controller
```

O ClusterRoleBinding é necessária para ligar a ClusteRole a ServiceAccount, estas configurações podem varificar em diversos cenários por exemplo na AWS é possível associar as roles de permissão da AWS diretamente para uma ServiceAccount.

**Deployment**

```
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ksha-aws-cw-controller
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ksha-aws-cw-controller
  template:
    metadata:
      labels:
        app: ksha-aws-cw-controller
    spec:
      serviceAccountName: ksha-controller
      containers:
      - name: ksha-aws-cw-controller
        image: krenek/ksha:latest
        env:
        - name: ACTIVE_SCALE
          value: "true"
        - name: NAMESPACE
          value: "workers-testing"
        - name: DEPLOYMENT
          value: "deployment-sidekiq"
        - name: AWS_DEFAULT_REGION
          value: "us-east-1"
        - name: AWS_ACCESS_KEY_ID
          value: "XXX"
        - name: AWS_SECRET_ACCESS_KEY
          value: "YYY"
        - name: REDIS_CLUSTER
          value: "cluster-001"
        - name: METRIC_SCRIPT
          value: "aws-elasticache-curritens" 
        - name: CONDITIONS
          value: "0=1 1000=2 2000=3 3000=4 4100=5 9000=10"
```
O deployment é o objeto do qual tem a responsabilidade de criar o container e executar o controlador no kubernetes as configurações do controlador são feitas através das variáveis de ambiente do deployment, neste exemplo estamos habilitando um controlador que recebe métricas de um script chamado aws-elasticache-curritens do qual faz a coleta a cada 60 segundos da quantidade de items de um cluster redis do AWS Elasticache (`metrics.d/aws-elasticache-curritens.sh`).

**Variáveis de ambiente**

As variáveis de ambiente podem variar conforme as customizações de métricas porém algumas são essenciais para o funcionamento do controlador, abaixo vamos separar as variáveis/configurações com base no exemplo utilizado uma parte para o controlador e a outra para o script de coleta das métricas:

*Variáveis para o uso do controlador:*

| Nome          | Descrição                              | Exemplo         |
| --------------|:--------------------------------------:| ---------------:|
| ACTIVE_SCALE  | Habilita a função de scale             | true            |
| NAMESPACE     | Nome da Namespace no kubernentes       | workers         |
| DEPLOYMENT    | Nome do Deployment no kubernentes      | sidekiq1        |
| METRIC_SCRIPT | Nome do script para coleta de métricas | redis           |
| CONDITIONS    | Condições/Regras do autoscale          | 0=1 10=5 100=10 |

*Variáveis para o uso do script de coleta de métricas aws-elasticache-curritens.sh:*

| Nome                  | Descrição                          | Exemplo     |
| ----------------------|:----------------------------------:| -----------:|
| AWS_DEFAULT_REGION    | Região da AWS                      | us-east-1   |
| AWS_ACCESS_KEY_ID     | ACCESS_KEY Para acessar CloudWatch | XYZ         |
| AWS_SECRET_ACCESS_KEY | AWS_SECRET_ACCESS_KEY              | XYZ         |
| REDIS_CLUSTER         | Nome do cluster Elasticache        | cluster-001 |

**Finalizando instalação**

Considerando o exemplo acima de utilização do script `aws-elasticache-curritens.sh` para coleta de métricas, após atualizar o deployment com as configurações necessárias basta aplicar ele em seu cluster kubernetes com o kubectl:

`kubectl -n <nomedanamespace> deployment.yaml`

**Considerações finais**

Como mecionado no inicio deste documento, este projeto é BETA e foi criado a princípio para validação de uma prova de conceito.
Estamos abertos para receber sugestões, críticas e colaborações de forma geral, em breve iremos adicionar novos exemplos e meios de coletas de métricas para amplificar as possibilidades uso.

**Stack de homologação**

`AWS EKS Kubernetes v1.17.12`

```
kubectl -n xxx logs ksha-aws-cw-controller-xxx
[CURRENT_VALUE: 4280 MIN_VALUE: 4200 SCALE 3 PODS - ACTIVE_SCALE: true]
[SCALE 3 PODS on deployment-yyy]
[CURRENT_VALUE: 4296 MIN_VALUE: 4200 SCALE 3 PODS - ACTIVE_SCALE: true]
[CURRENT_VALUE: 4254 MIN_VALUE: 4200 SCALE 3 PODS - ACTIVE_SCALE: true]
[CURRENT_VALUE: 4179 MIN_VALUE: 4100 SCALE 2 PODS - ACTIVE_SCALE: true]
[SCALE 2 PODS on deployment-yyy]
[CURRENT_VALUE: 4142 MIN_VALUE: 4100 SCALE 2 PODS - ACTIVE_SCALE: true]
[CURRENT_VALUE: 4094 MIN_VALUE: 4000 SCALE 4 PODS - ACTIVE_SCALE: true]
[SCALE 4 PODS on deployment-yyy]
[CURRENT_VALUE: 4021 MIN_VALUE: 4000 SCALE 4 PODS - ACTIVE_SCALE: true]
[CURRENT_VALUE: 3967 MIN_VALUE: 3800 SCALE 3 PODS - ACTIVE_SCALE: true]
[SCALE 3 PODS on deployment-yyy]
[CURRENT_VALUE: 3901 MIN_VALUE: 3800 SCALE 3 PODS - ACTIVE_SCALE: true]
```
