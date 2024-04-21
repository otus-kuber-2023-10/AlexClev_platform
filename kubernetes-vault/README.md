Создан кластер на базе yandex cloud из 3 нод:
# kubectl get nodes
NAME           STATUS   ROLES           AGE   VERSION
cl1g0lr56jbhjkbp3dn9-arid   Ready    <none>   14d     v1.26.2
cl1g0lr56jbhjkbp3dn9-egyr   Ready    <none>   9d      v1.26.2
cl1g0lr56jbhjkbp3dn9-eqot   Ready    <none>   8m50s   v1.26.2

Указанный в методичке репозиторий консула древний и в рахиве, переходим по свежей ссылке и качаем:

git clone https://github.com/hashicorp/consul-k8s.git

Ноды нужно 3 , что и укажем в файлике  consul.values.yaml.
ну и ставим:
# helm upgrade --install consul ./consul-k8s/charts/consul --namespace consul --create-namespace -f ./consul-k8s/consul.values.yaml

Release "consul" does not exist. Installing it now.
NAME: consul
LAST DEPLOYED: Thu Apr 18 21:04:23 2024
NAMESPACE: consul
STATUS: deployed
REVISION: 1
NOTES:
Thank you for installing HashiCorp Consul!

Your release is named consul.

To learn more about the release, run:

  $ helm status consul --namespace consul
  $ helm get all consul --namespace consul

Проверяем участников кластера консул:
# kubectl exec -it consul-server-0 -n consul -c consul -- consul members
Node             Address             Status  Type    Build      Protocol  DC   Partition  Segment
consul-server-0  172.16.19.85:8301   alive   server  1.19.0dev  2         dc1  default    <all>
consul-server-1  172.16.18.214:8301  alive   server  1.19.0dev  2         dc1  default    <all>
consul-server-2  172.16.19.19:8301   alive   server  1.19.0dev  2         dc1  default    <all>


Клонируем git vault, создаём vault.values.yaml по методичке и ставим vault-helm: 

# helm upgrade --install vault ./vault-helm --namespace vault --create-namespace -f ./vault-helm/vault.values.yaml
Release "consul" does not exist. Installing it now.
NAME: consul
LAST DEPLOYED: Thu Apr 18 21:04:23 2024
NAMESPACE: consul
STATUS: deployed
REVISION: 1
NOTES:
Thank you for installing HashiCorp Consul!

Your release is named consul.

To learn more about the release, run:

  $ helm status consul --namespace consul
  $ helm get all consul --namespace consul


# helm status vault -n vault
NAME: vault
LAST DEPLOYED: Thu Apr 18 21:09:16 2024
NAMESPACE: vault
STATUS: deployed
REVISION: 1
NOTES:
Thank you for installing HashiCorp Vault!

# kubectl get pods -n vault -o wide
NAME                                    READY   STATUS    RESTARTS   AGE   IP              NODE                        NOMINATED NODE   READINESS GATES
vault-0                                 0/1     Running   0          22m   172.16.19.67    cl1g0lr56jbhjkbp3dn9-ucyb   <none>           <none>
vault-1                                 0/1     Running   0          22m   172.16.19.4     cl1g0lr56jbhjkbp3dn9-yzit   <none>           <none>
vault-2                                 0/1     Running   0          22m   172.16.18.196   cl1g0lr56jbhjkbp3dn9-ylef   <none>           <none>
vault-agent-injector-784f844f68-qp8fp   1/1     Running   0          22m   172.16.18.195   cl1g0lr56jbhjkbp3dn9-ylef   <none>           <none>

Смотрим логи:

# kubectl logs vault-0 -n vault --tail 2
2024-04-18T18:11:44.475Z [WARN]  storage migration check error: error="Get \"http://10.129.0.4:8500/v1/kv/vault/core/migration\": dial tcp 10.129.0.4:8500: connect: connection refused"
2024-04-18T18:11:46.476Z [WARN]  storage migration check error: error="Get \"http://10.129.0.4:8500/v1/kv/vault/core/migration\": dial tcp 10.129.0.4:8500: connect: connection refused"

Модернизируем vault.values.yaml, добавив конфигурацию для подключения с сервису Consul в секции server/ha, применим повторно и проверим:

# kubectl logs vault-0 -n vault --tail 2
2024-04-21T15:57:48.996Z [INFO]  core: security barrier not initialized
2024-04-21T15:57:48.997Z [INFO]  core: seal configuration missing, not initialized

Кластер не инициализирован, исправим это:
Параметрами --key-shares и --key-threshold можно позадачать количество сегметнов главного ключа и требуемое числе сегметнов для восстновления (алгоритм Shamir's Secret Sharing), но мы бедем использовать один сегмент.
# kubectl exec -it vault-0 -n vault -- vault operator init --key-shares=1 --key-threshold=1
Unseal Key 1: RPDQGrduwC9BIxMFYRHAgAZUYkbozwl5FbROJ2xXly4=

Initial Root Token: hvs.nT4ues5Iu8we7kNFI2jnoz7M

Vault initialized with 1 key shares and a key threshold of 1. Please securely
distribute the key shares printed above. When the Vault is re-sealed,
restarted, or stopped, you must supply at least 1 of these keys to unseal it
before it can start servicing requests.

Vault does not store the generated root key. Without at least 1 keys to
reconstruct the root key, Vault will remain permanently sealed!

It is possible to generate new unseal keys, provided you have a quorum of
existing unseal keys shares. See "vault operator rekey" for more information.



Проверим состояние:
# kubectl exec -it vault-0 -n vault -- vault status
Key                Value
---                -----
Seal Type          shamir
Initialized        true
Sealed             true
Total Shares       1
Threshold          1
Unseal Progress    0/1
Unseal Nonce       n/a
Version            1.16.1
Build Date         2024-04-03T12:35:53Z
Storage Type       consul
HA Enabled         true
command terminated with exit code 2

Инициализация успешная (Initialized:true) , но пока кластер запечатан ( Sealed:true).

Заглянем в переменные окружения
# kubectl exec -it vault-0 -n vault env | grep VAULT
kubectl exec [POD] [COMMAND] is DEPRECATED and will be removed in a future version. Use kubectl exec [POD] -- [COMMAND] instead.
VAULT_K8S_POD_NAME=vault-0
VAULT_K8S_NAMESPACE=vault
VAULT_ADDR=http://127.0.0.1:8200
VAULT_API_ADDR=http://172.16.19.93:8200
VAULT_CLUSTER_ADDR=https://vault-0.vault-internal:8201
VAULT_AGENT_INJECTOR_SVC_PORT_443_TCP_PORT=443
VAULT_UI_PORT=tcp://172.16.23.7:8200
VAULT_PORT_8200_TCP_PROTO=tcp
VAULT_STANDBY_PORT=tcp://172.16.23.90:8200
VAULT_PORT=tcp://172.16.23.2:8200
VAULT_PORT_8201_TCP_ADDR=172.16.23.2
VAULT_ACTIVE_SERVICE_PORT_HTTPS_INTERNAL=8201
...

Распечатываем кластер на каждом поде. Сегмент ключа один, так что по одной команде на каждом:

# kubectl exec -it vault-0  -n vault -- vault operator unseal 'RPDQGrduwC9BIxMFYRHAgAZUYkbozwl5FbROJ2xXly4='
# kubectl exec -it vault-1  -n vault -- vault operator unseal 'RPDQGrduwC9BIxMFYRHAgAZUYkbozwl5FbROJ2xXly4='
# kubectl exec -it vault-2  -n vault -- vault operator unseal 'RPDQGrduwC9BIxMFYRHAgAZUYkbozwl5FbROJ2xXly4='
Key             Value
---             -----
Seal Type       shamir
Initialized     true
Sealed          false
Total Shares    1
Threshold       1
Version         1.16.1
Build Date      2024-04-03T12:35:53Z
Storage Type    consul
Cluster Name    vault-cluster-ea04923d
Cluster ID      e6630cbb-7664-63fd-8117-c72275e4dd62
HA Enabled      true
HA Cluster      https://vault-0.vault-internal:8201
HA Mode         active
Active Since    2024-04-21T16:24:44.899958333Z

# kubectl exec -it vault-0 -n vault -- vault status
Key             Value
---             -----
Seal Type       shamir
Initialized     true
Sealed          false
Total Shares    1
Threshold       1
Version         1.16.1
Build Date      2024-04-03T12:35:53Z
Storage Type    consul
Cluster Name    vault-cluster-ea04923d
Cluster ID      e6630cbb-7664-63fd-8117-c72275e4dd62
HA Enabled      true
HA Cluster      https://vault-0.vault-internal:8201
HA Mode         active
Active Since    2024-04-21T16:24:44.899958333Z

Отлично, кластер распечатан


делаем запрос к vault:
# kubectl exec -it vault-0 -n vault -- vault auth list
Error listing enabled authentications: Error making API request.

URL: GET http://127.0.0.1:8200/v1/sys/auth
Code: 403. Errors:

* permission denied

нет прав. Логинимся с помощью токена:

# kubectl exec -it vault-0 -n vault -- vault login
Token (will be hidden):
Success! You are now authenticated. The token information displayed below
is already stored in the token helper. You do NOT need to run "vault login"
again. Future Vault requests will automatically use this token.

Key                  Value
---                  -----
token                hvs.nT4ues5Iu8we7kNFI2jnoz7M
token_accessor       eASLUgcEcDstVAHGHow5qS1Q
token_duration       ∞
token_renewable      false
token_policies       ["root"]
identity_policies    []
policies             ["root"]

Повторяем:
# kubectl exec -it vault-0 -n vault -- vault auth list
Path      Type     Accessor               Description                Version
----      ----     --------               -----------                -------
token/    token    auth_token_bd075e70    token based credentials    n/a

заведем указанные ключи:
# kubectl exec -it vault-0 -n vault -- vault secrets enable --path=otus kv
Success! Enabled the kv secrets engine at: otus/
# kubectl exec -it vault-0 -n vault -- vault secrets list --detailed
Path          Plugin       Accessor              Default TTL    Max TTL    Force No Cache    Replication    Seal Wrap    External Entropy Access    Options    Description                                                UUID                                    Version    Running Version          Running SHA256    Deprecation Status
----          ------       --------              -----------    -------    --------------    -----------    ---------    -----------------------    -------    -----------                                                ----                                    -------    ---------------          --------------    ------------------
cubbyhole/    cubbyhole    cubbyhole_4ef116a0    n/a            n/a        false             local          false        false                      map[]      per-token private secret storage                           1680951b-3142-9c75-9d92-0706cc43cfbf    n/a        v1.16.1+builtin.vault    n/a               n/a
identity/     identity     identity_89f5f3d3     system         system     false             replicated     false        false                      map[]      identity store                                             ecd1fbe9-5f1a-8b35-ba69-ea5ecb40ba83    n/a        v1.16.1+builtin.vault    n/a               n/a
otus/         kv           kv_4d78a8e6           system         system     false             replicated     false        false                      map[]      n/a                                                        e15d992d-90a3-9be4-7c55-cea114139911    n/a        v0.17.0+builtin          n/a               supported
sys/          system       system_3b658f75       n/a            n/a        false             replicated     true         false                      map[]      system endpoints used for control, policy and debugging    c41237c8-186a-0a12-4328-bbc8a6ff5151    n/a        v1.16.1+builtin.vault    n/a               n/a

# kubectl exec -it vault-0 -n vault -- vault kv put otus/otus-ro/config username='otus' password='asajkjkahs'
Success! Data written to: otus/otus-ro/config

# kubectl exec -it vault-0 -n vault -- vault kv put otus/otus-rw/config username='otus' password='asajkjkahs'
Success! Data written to: otus/otus-rw/config

# kubectl exec -it vault-0 -n vault -- vault read otus/otus-ro/config
Key                 Value
---                 -----
refresh_interval    768h
password            asajkjkahs
username            otus

# kubectl exec -it vault-0 -n vault -- vault kv get otus/otus-rw/config
====== Data ======
Key         Value
---         -----
password    asajkjkahs
username    otus

Включим авторизацию черерз k8s

#  kubectl exec -it vault-0 -n vault -- vault auth enable kubernetes
Success! Enabled kubernetes auth method at: kubernetes/
# kubectl exec -it vault-0 -n vault -- vault auth list
Path           Type          Accessor                    Description                Version
----           ----          --------                    -----------                -------
kubernetes/    kubernetes    auth_kubernetes_ed4e91ec    n/a                        n/a
token/         token         auth_token_bd075e70         token based credentials    n/a

Создадим сервисный аккаунт, манифест ClusterRoleBinding и применим его

# kubectl create serviceaccount vault-auth
serviceaccount/vault-auth created
# kubectl apply --filename vault-auth-service-account.yml
clusterrolebinding.rbac.authorization.k8s.io/role-tokenreview-binding created

Готовим  переменные для записи в конфиг кубер авторизации
# export VAULT_SA_NAME=$(kubectl get sa vault-auth -o jsonpath="{.secrets[*]['name']}")
# export SA_JWT_TOKEN=$(kubectl get secret $VAULT_SA_NAME -o jsonpath="{.data.token}" | base64 --decode; echo) 
# export SA_CA_CRT=$(kubectl get secret $VAULT_SA_NAME -o jsonpath="{.data['ca\.crt']}" |  base64 --decode; echo)  
# export K8S_HOST=$(more ~/.kube/config | grep server |awk '/http/ {print $NF}')

Пробуем записать в Vault
# kubectl exec -it vault-0 -n vault -- vault write auth/kubernetes/config token_reviewer_jwt="$SA_JWT_TOKEN" kubernetes_host="$K8S_HOST" kubernetes_ca_cert="$SA_CA_CRT"
Success! Data written to: auth/kubernetes/config

Команда sed ’s/\x1b[[0-9;]*m//g’  может взять значение K8S_HOST в виде escape-последовательности ANSI из вывода команды kubectl cluster-info

Создаем политику для Vault в файле otus-policy.hcl и применяем:

# kubectl cp -n vault otus-policy.hcl vault-0:./
tar: can't open 'otus-policy.hcl': Permission denied
command terminated with exit code 1
Во как..методичка врёт, как обычно. Пробуем закинуть в tmp:
# kubectl cp -n vault otus-policy.hcl vault-0:/tmp
# kubectl exec -it vault-0 -n vault -- vault policy write otus-policy /tmp/otus-policy.hcl
Success! Uploaded policy: otus-policy

Создаем роль для доступа УЗ vault-auth в namespace default, согласно политике otus-policy сроком на 24 часа:
# kubectl exec -it vault-0 -n vault -- vault write auth/kubernetes/role/otus bound_service_account_names=vault-auth bound_service_account_namespaces=default policies=otus-policy ttl=24h
Success! Data written to: auth/kubernetes/role/otus


Создаем стестовый Pod c привязанным сервсиный аккаунтом
# kubectl run --generator=run-pod/v1 tmp --rm -i --tty --serviceaccount=vault-auth --image alpine:3.19
error: unknown flag: --generator
See 'kubectl run --help' for usage.
Читаем, что опция "--generator" устарела сто лет  как...неужели трудно подправить методички???

# kubectl run tmp --rm -i --tty --overrides='{ "spec": { "serviceAccount": "vault-auth" }  }' --image alpine:3.19
If you don't see a command prompt, try pressing enter.
# apk add curl jq
fetch https://dl-cdn.alpinelinux.org/alpine/v3.19/main/x86_64/APKINDEX.tar.gz
fetch https://dl-cdn.alpinelinux.org/alpine/v3.19/community/x86_64/APKINDEX.tar.gz
(1/10) Installing ca-certificates (20240226-r0)
(2/10) Installing brotli-libs (1.1.0-r1)
(3/10) Installing c-ares (1.27.0-r0)
(4/10) Installing libunistring (1.1-r2)
(5/10) Installing libidn2 (2.3.4-r4)
(6/10) Installing nghttp2-libs (1.58.0-r0)
(7/10) Installing libcurl (8.5.0-r0)
(8/10) Installing curl (8.5.0-r0)
(9/10) Installing oniguruma (6.9.9-r0)
(10/10) Installing jq (1.7.1-r0)
Executing busybox-1.36.1-r15.trigger
Executing ca-certificates-20240226-r0.trigger
OK: 13 MiB in 25 packages
# VAULT_ADDR=http://vault:8200
# KUBE_TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
# curl --request POST --data '{"jwt": "'$KUBE_TOKEN'", "role": "otus"}' $VAULT_ADDR/v1/auth/kubernetes/login | jq
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
  0     0    0     0    0     0      0      0 --:--:-- --:--:-- --:--:--     0curl: (6) Could not resolve host: vault
Отлично...

Забиваем на методичку в очередной раз и думаем сами
 # VAULT_ADDR=http://vault.vault:8200
 # KUBE_TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
 # curl -s --request POST --data '{"jwt": "'$KUBE_TOKEN'", "role": "otus"}' $VAULT_ADDR/v1/auth/kubernetes/login | jq
{
  "request_id": "767f4354-ae09-29df-3c92-6e5ed8f2e55f",
  "lease_id": "",
  "renewable": false,
  "lease_duration": 0,
  "data": null,
  "wrap_info": null,
  "warnings": null,
  "auth": {
    "client_token": "hvs.CAESINd64TSerS1LPUiZmDJgJxlBxhsa4Zr7buy1PajwXcsQGh4KHGh2cy5weXlpQ0tNQUxNMWlBaVYwU1VUem5naUk",
    "accessor": "WxEW8523Kjk1zSf5lTZddGVb",
    "policies": [
      "default",
      "otus-policy"
    ],
    "token_policies": [
      "default",
      "otus-policy"
    ],
    "metadata": {
      "role": "otus",
      "service_account_name": "vault-auth",
      "service_account_namespace": "default",
      "service_account_secret_name": "",
      "service_account_uid": "4ce3a724-ddad-4cb3-ae46-2f97fc420a3d"
    },
    "lease_duration": 86400,
    "renewable": true,
    "entity_id": "ad28810b-545e-1750-c44d-dddf8a0718fa",
    "token_type": "service",
    "orphan": true,
    "mfa_requirement": null,
    "num_uses": 0
  },
  "mount_type": ""
}
# TOKEN=$(curl -k -s --request POST --data '{"jwt": "'$KUBE_TOKEN'", "role": "test"}' $VAULT_ADDR/v1/auth/kubernetes/login | jq '.auth.client_token' | awk -F\" '{print $2}')

# curl -s --header "X-Vault-Token: $TOKEN" $VAULT_ADDR/v1/otus/otus-ro/config | jq
{
  "errors": [
    "permission denied"
  ]

С токеном что-то не то. Пробуем подправить:
# TOKEN=$(curl -s --request POST --data '{"jwt": "'$KUBE_TOKEN'", "role": "otus"}' $VAULT_ADDR/v1/auth/kubernetes/login | jq -r .auth.client_token)

# curl -s --header "X-Vault-Token: $TOKEN" $VAULT_ADDR/v1/otus/otus-ro/config | jq
{
  "request_id": "4ea5dad4-f31a-7cbb-0ce8-4cc7f1c8eff9",
  "lease_id": "",
  "renewable": false,
  "lease_duration": 2764800,
  "data": {
    "password": "asajkjkahs",
    "username": "otus"
  },
  "wrap_info": null,
  "warnings": null,
  "auth": null,
  "mount_type": "kv"
}
# curl -s --header "X-Vault-Token: $TOKEN" $VAULT_ADDR/v1/otus/otus-rw/config | jq
{
  "request_id": "aa4ccde5-2fa9-53b9-2ed9-e20594e72283",
  "lease_id": "",
  "renewable": false,
  "lease_duration": 2764800,
  "data": {
    "password": "asajkjkahs",
    "username": "otus"
  },
  "wrap_info": null,
  "warnings": null,
  "auth": null,
  "mount_type": "kv"
}

Проверяем запись
 # curl --request POST --data '{"bar": "baz"}' --header "X-Vault-Token: $TOKEN" $VAULT_ADDR/v1/otus/otus-ro/config
{"errors":["1 error occurred:\n\t* permission denied\n\n"]}
 # curl --request POST --data '{"bar": "baz"}' --header "X-Vault-Token: $TOKEN" $VAULT_ADDR/v1/otus/otus-rw/config
{"errors":["1 error occurred:\n\t* permission denied\n\n"]}
 # curl --request POST --data '{"bar": "baz"}' --header "X-Vault-Token: $TOKEN" $VAULT_ADDR/v1/otus/otus-rw/config1

Записались тольок в новый файл, потому как наша политика не разрешает обновление данных. Добавляем update в файл otus-policy.hcl и применем её снова
 # curl --request POST --data '{"bar": "baz"}' --header "X-Vault-Token: $TOKEN" $VAULT_ADDR/v1/otus/otus-ro/config
{"errors":["1 error occurred:\n\t* permission denied\n\n"]}
 # curl --request POST --data '{"bar": "baz"}' --header "X-Vault-Token: $TOKEN" $VAULT_ADDR/v1/otus/otus-rw/config1
 # curl --request POST --data '{"bar": "baz"}' --header "X-Vault-Token: $TOKEN" $VAULT_ADDR/v1/otus/otus-rw/config
В этот раз не спогли записать только в read only , что и требовалось


Тестируем авторизацию

Копируем репозиторий с примерами:

git clone https://github.com/hashicorp/vault-guides.git

Правим конфиги и применяем:
# kubectl apply -f configmap.yaml
configmap/example-vault-agent-config created
# kubectl apply -f example-k8s-spec.yaml
pod/vault-agent-example created

# kubectl get configmap example-vault-agent-config -o yaml
apiVersion: v1
data:
  vault-agent-config.hcl: |
    # Comment this out if running as sidecar instead of initContainer
    exit_after_auth = true

    pid_file = "/home/vault/pidfile"

    auto_auth {
        method "kubernetes" {
            mount_path = "auth/kubernetes"
            config = {
                role = "otus"
            }
        }

        sink "file" {
            config = {
                path = "/home/vault/.vault-token"
            }
        }
    }

    template {
    destination = "/etc/secrets/index.html"
    contents = <<EOT
    <html>
    <body>
    <p>Some secrets:</p>
    {{- with secret "otus/otus-ro/config" }}
    <ul>
    <li><pre>username: {{ .Data.username }}</pre></li>
    <li><pre>password: {{ .Data.password }}</pre></li>
    </ul>
    {{ end }}
    </body>
    </html>
    EOT
    }
kind: ConfigMap
metadata:
  annotations:
    kubectl.kubernetes.io/last-applied-configuration: |
      {"apiVersion":"v1","data":{"vault-agent-config.hcl":"# Comment this out if running as sidecar instead of initContainer\nexit_after_auth = true\n\npid_file = \"/home/vault/pidfile\"\n\nauto_auth {\n    method \"kubernetes\" {\n        mount_path = \"auth/kubernetes\"\n        config = {\n            role = \"otus\"\n        }\n    }\n\n    sink \"file\" {\n        config = {\n            path = \"/home/vault/.vault-token\"\n        }\n    }\n}\n\ntemplate {\ndestination = \"/etc/secrets/index.html\"\ncontents = \u003c\u003cEOT\n\u003chtml\u003e\n\u003cbody\u003e\n\u003cp\u003eSome secrets:\u003c/p\u003e\n{{- with secret \"otus/otus-ro/config\" }}\n\u003cul\u003e\n\u003cli\u003e\u003cpre\u003eusername: {{ .Data.username }}\u003c/pre\u003e\u003c/li\u003e\n\u003cli\u003e\u003cpre\u003epassword: {{ .Data.password }}\u003c/pre\u003e\u003c/li\u003e\n\u003c/ul\u003e\n{{ end }}\n\u003c/body\u003e\n\u003c/html\u003e\nEOT\n}\n"},"kind":"ConfigMap","metadata":{"annotations":{},"name":"example-vault-agent-config","namespace":"default"}}
  creationTimestamp: "2024-04-21T19:14:35Z"
  name: example-vault-agent-config
  namespace: default
  resourceVersion: "166496"
  uid: 4d8fa5f5-c34e-4bdc-9058-a486bbc81739

# kubectl get pods
NAME                  READY   STATUS    RESTARTS   AGE
tmp                   1/1     Running   0          70m
vault-agent-example   1/1     Running   0          6m28s

  Вытащим index
kubectl exec -it vault-agent-example -c nginx-container -- cat /usr/share/nginx/html/index.html
<html>
<body>
<p>Some secrets:</p>
<ul>
<li><pre>username: otus</pre></li>
<li><pre>password: asajkjkahs</pre></li>
</ul>

</body>
</html>


Включим pki secrets

# kubectl exec -it -n vault vault-0 -- vault secrets enable pki
Success! Enabled the pki secrets engine at: pki/
# kubectl exec -it -n vault vault-0 -- vault secrets list
Path          Type         Accessor              Description
----          ----         --------              -----------
cubbyhole/    cubbyhole    cubbyhole_4ef116a0    per-token private secret storage
identity/     identity     identity_89f5f3d3     identity store
otus/         kv           kv_4d78a8e6           n/a
pki/          pki          pki_429c00dc          n/a
sys/          system       system_3b658f75       system endpoints used for control, policy and debugging
# kubectl exec -it -n vault vault-0 -- vault secrets tune -max-lease-ttl=87600h pki
Success! Tuned the secrets engine at: pki/
# kubectl exec -it -n vault vault-0 -- vault write -field=certificate pki/root/generate/internal common_name="exmaple.ru" ttl=87600h > CA_cert.crt

# kubectl exec -it -n vault vault-0 -- vault write pki/config/urls issuing_certificates="http://vault.vault:8200/v1/pki/ca" crl_distribution_points="http://vault.vault:8200/v1/pki/crl"
Key                        Value
---                        -----
crl_distribution_points    [http://vault.vault:8200/v1/pki/crl]
enable_templating          false
issuing_certificates       [http://vault.vault:8200/v1/pki/ca]
ocsp_servers               []

# kubectl exec -it -n vault vault-0 -- vault secrets enable --path=pki_int pki
Success! Enabled the pki secrets engine at: pki_int/
# kubectl exec -it -n vault vault-0  -- vault secrets tune -max-lease-ttl=87600h pki_int
Success! Tuned the secrets engine at: pki_int/
# kubectl exec -it -n vault vault-0  -- vault write -format=json pki_int/intermediate/generate/internal common_name="example.ru Intermediate Authority" | jq -r '.data.csr' > pki_intermediate.csr
# kubectl cp -n vault  pki_intermediate.csr vault-0:/tmp 
# kubectl exec -n vault -it vault-0 -- vault write -format=json pki/root/sign-intermediate csr=@/tmp/pki_intermediate.csr format=pem_bundle ttl="43800h" | jq -r '.data.certificate' > intermediate.cert.pem
# kubectl cp -n vault intermediate.cert.pem vault-0:/tmp
# kubectl exec -n vault -it vault-0 -- vault write pki_int/intermediate/set-signed certificate=@/tmp/intermediate.cert.pem
WARNING! The following warnings were returned from Vault:

  * This mount hasn't configured any authority information access (AIA)
  fields; this may make it harder for systems to find missing certificates
  in the chain or to validate revocation status of certificates. Consider
  updating /config/urls or the newly generated issuer with this information.

Key                 Value
---                 -----
existing_issuers    <nil>
existing_keys       <nil>
imported_issuers    [e9992e91-1182-eae3-3f68-601ec25a1a32 5fae2e35-7cd5-1da6-dc4c-95fe8c51b88b]
imported_keys       <nil>
mapping             map[5fae2e35-7cd5-1da6-dc4c-95fe8c51b88b: e9992e91-1182-eae3-3f68-601ec25a1a32:23942189-ea85-5add-4197-85a4eed03d1f]

# cat intermediate.cert.pem
-----BEGIN CERTIFICATE-----
MIIDqDCCApCgAwIBAgIUY3OJANBaAFGaBskZypYvltS8XLYwDQYJKoZIhvcNAQEL
BQAwFTETMBEGA1UEAxMKZXhtYXBsZS5ydTAeFw0yNDA0MjEyMDAwMDVaFw0yOTA0
MjAyMDAwMzVaMCwxKjAoBgNVBAMTIWV4YW1wbGUucnUgSW50ZXJtZWRpYXRlIEF1
dGhvcml0eTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAJKXrw3bA/Rh
PvNpoxMHzmy/5ucABFQGOqRbTE1o44zGLsDAnNk3bLnWsP68ut8WsNWAUCox/tWf
L9nFZxO0zIS537gNDP3Vqq2IeMWPjGK4eR7emVjZXsFlW80wwrsTrgv/jlc1NKHH
z9trP4Lpv+ci8UrvLYEr9dQKvQDXnK9/UlsRtroFbYVMzVl1rgdXy+gt7axfFq7x
NVvkLc4O1uvXFPIEfpqHU1eCpnoDOLTaAcIwG3fQx5WmwCmLARecE1Kgf7sp9Ejz
jCYElcPEwt9AkKHq8/YOSoheRUGiNl5ksvQZrpIyTIXPIxsRFw9jBebaHTZImuav
bHMGhtoGwLECAwEAAaOB2DCB1TAOBgNVHQ8BAf8EBAMCAQYwDwYDVR0TAQH/BAUw
AwEB/zAdBgNVHQ4EFgQUKFCK9XLV4gOaCO9PkMRI1uLN/1MwHwYDVR0jBBgwFoAU
LIDRyeznNndSVKsJIQ/FQiJw+EYwPQYIKwYBBQUHAQEEMTAvMC0GCCsGAQUFBzAC
hiFodHRwOi8vdmF1bHQudmF1bHQ6ODIwMC92MS9wa2kvY2EwMwYDVR0fBCwwKjAo
oCagJIYiaHR0cDovL3ZhdWx0LnZhdWx0OjgyMDAvdjEvcGtpL2NybDANBgkqhkiG
9w0BAQsFAAOCAQEAQI/v31vqlTkT9no7t62V6hvL8LPTMV/OIEM+YHoVV+SPF4m/
P0TxHz0XK7U0O71EMWRv+PT8xDx/PE50bVeFyNARUBz4njKDJgtY2DOFA4UtZuFi
pSheMeZDccRQLJWsXhob6vXa2SHzNv1V0EN59OSAttbT1YA/L12oKgklfyoTZTbv
KTtDzxVdJCq646j7S9e7nRUmf6uBsNewIJGPv+fwo89KNJRGrV9+xI5YhA5ktRN2
cv3Cahwd9ZfVPl7TTW3uF/4W8gIitPv2S/Sy0tGVOq/8eeO5VLw+n7eDQhTTfV1K
o2dTEWEeYpIvInTKzhBsD4mbv+9s/HHvJ7BYYw==
-----END CERTIFICATE-----
-----BEGIN CERTIFICATE-----
MIIDMjCCAhqgAwIBAgIUSWSn9gNdT/UqWgyqkfKGhK6XE14wDQYJKoZIhvcNAQEL
BQAwFTETMBEGA1UEAxMKZXhtYXBsZS5ydTAeFw0yNDA0MjExOTM0NDdaFw0zNDA0
MTkxOTM1MTdaMBUxEzARBgNVBAMTCmV4bWFwbGUucnUwggEiMA0GCSqGSIb3DQEB
AQUAA4IBDwAwggEKAoIBAQDhaBE0dCdaWlf/I+RPX9d1kBN6r/TOmgxXh7sDvlJ7
X8bjgQYzOC5TNseUYWAXiBCNxfcUct1WThXd4kiR3ND6G9dV/Cuu4yk7zn8GS3zj
1Vxj9SmrXN0CtPXDBNrqD1bvFyPqhXWrmOqZ6YuSaTQLZZ3cTTW3McbyWrx9E//v
vKGXfdGKNKJxlcA8zTS1t6B0zOf1ZNhyjFBoKXRfNbA919f9DZjSsExQewzezOMa
nKB1TeCrygzIcLNXlC5lL5t428RG31Hs7HrXDif1xdWGB4WfkWk0I3lGAQt8V9e1
mjhEype6CngBFjltk3zestnCBnG0l+edkPQVuEvUIEiBAgMBAAGjejB4MA4GA1Ud
DwEB/wQEAwIBBjAPBgNVHRMBAf8EBTADAQH/MB0GA1UdDgQWBBQsgNHJ7Oc2d1JU
qwkhD8VCInD4RjAfBgNVHSMEGDAWgBQsgNHJ7Oc2d1JUqwkhD8VCInD4RjAVBgNV
HREEDjAMggpleG1hcGxlLnJ1MA0GCSqGSIb3DQEBCwUAA4IBAQAgp/sGI+KEietN
s8x5o03CJG79AobgNJh7isu7odiJxNhi1CzCRnWbNwNT8e+rUnEvWtRdCYxPLW4r
/sMFfFHy54hZ0GCsBQRzRo1vDhGVs9hjtXBzKq7Zt4ZqW+/eWGcCPklRK9YuJKa5
rBVw+o93JJ0mvjuGgeMHdlBGxm46Ali1VnzS01VFiB/wZvuT0OBJN3XCe35CbsMc
0flYH3+T3hrAOyfrtFwQKO4+75TSTehSZAlzfxXMr9ma+wMcEyF5JzOSMNr/Vyyp
YBlxglA15ibRrJxDyXqgsli5Y0xgiRIbja//kzDJZNzpQsYnqsxvE0BCwaSw1TpL
LtVG9MXE
-----END CERTIFICATE-----


Создаем роль для выдачи сертификатов

# kubectl exec -it -n vault vault-0 -- vault write pki_int/roles/example-dot-ru allowed_domains="example.ru" allow_subdomains=true max_ttl="720h"                 Key                                   Value
---                                   -----
allow_any_name                        false
allow_bare_domains                    false
allow_glob_domains                    false
allow_ip_sans                         true
allow_localhost                       true
allow_subdomains                      true
allow_token_displayname               false
allow_wildcard_certificates           true
allowed_domains                       [example.ru]
allowed_domains_template              false
allowed_other_sans                    []
allowed_serial_numbers                []
allowed_uri_sans                      []
allowed_uri_sans_template             false
allowed_user_ids                      []
basic_constraints_valid_for_non_ca    false
client_flag                           true
cn_validations                        [email hostname]
code_signing_flag                     false
country                               []
email_protection_flag                 false
enforce_hostnames                     true
ext_key_usage                         []
ext_key_usage_oids                    []
generate_lease                        false
issuer_ref                            default
key_bits                              2048
key_type                              rsa
key_usage                             [DigitalSignature KeyAgreement KeyEncipherment]
locality                              []
max_ttl                               720h
no_store                              false
not_after                             n/a
not_before_duration                   30s
organization                          []
ou                                    []
policy_identifiers                    []
postal_code                           []
province                              []
require_cn                            true
server_flag                           true
signature_bits                        256
street_address                        []
ttl                                   0s
use_csr_common_name                   true
use_csr_sans                          true
use_pss                               false

Создадим и отзовем сертификат

 kubectl exec -it -n vault vault-0 -- vault write pki_int/issue/example-dot-ru common_name="gitlab.example.ru" ttl="24h"
Key                 Value
---                 -----
ca_chain            [-----BEGIN CERTIFICATE-----
MIIDqDCCApCgAwIBAgIUY3OJANBaAFGaBskZypYvltS8XLYwDQYJKoZIhvcNAQEL
BQAwFTETMBEGA1UEAxMKZXhtYXBsZS5ydTAeFw0yNDA0MjEyMDAwMDVaFw0yOTA0
MjAyMDAwMzVaMCwxKjAoBgNVBAMTIWV4YW1wbGUucnUgSW50ZXJtZWRpYXRlIEF1
dGhvcml0eTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAJKXrw3bA/Rh
PvNpoxMHzmy/5ucABFQGOqRbTE1o44zGLsDAnNk3bLnWsP68ut8WsNWAUCox/tWf
L9nFZxO0zIS537gNDP3Vqq2IeMWPjGK4eR7emVjZXsFlW80wwrsTrgv/jlc1NKHH
z9trP4Lpv+ci8UrvLYEr9dQKvQDXnK9/UlsRtroFbYVMzVl1rgdXy+gt7axfFq7x
NVvkLc4O1uvXFPIEfpqHU1eCpnoDOLTaAcIwG3fQx5WmwCmLARecE1Kgf7sp9Ejz
jCYElcPEwt9AkKHq8/YOSoheRUGiNl5ksvQZrpIyTIXPIxsRFw9jBebaHTZImuav
bHMGhtoGwLECAwEAAaOB2DCB1TAOBgNVHQ8BAf8EBAMCAQYwDwYDVR0TAQH/BAUw
AwEB/zAdBgNVHQ4EFgQUKFCK9XLV4gOaCO9PkMRI1uLN/1MwHwYDVR0jBBgwFoAU
LIDRyeznNndSVKsJIQ/FQiJw+EYwPQYIKwYBBQUHAQEEMTAvMC0GCCsGAQUFBzAC
hiFodHRwOi8vdmF1bHQudmF1bHQ6ODIwMC92MS9wa2kvY2EwMwYDVR0fBCwwKjAo
oCagJIYiaHR0cDovL3ZhdWx0LnZhdWx0OjgyMDAvdjEvcGtpL2NybDANBgkqhkiG
9w0BAQsFAAOCAQEAQI/v31vqlTkT9no7t62V6hvL8LPTMV/OIEM+YHoVV+SPF4m/
P0TxHz0XK7U0O71EMWRv+PT8xDx/PE50bVeFyNARUBz4njKDJgtY2DOFA4UtZuFi
pSheMeZDccRQLJWsXhob6vXa2SHzNv1V0EN59OSAttbT1YA/L12oKgklfyoTZTbv
KTtDzxVdJCq646j7S9e7nRUmf6uBsNewIJGPv+fwo89KNJRGrV9+xI5YhA5ktRN2
cv3Cahwd9ZfVPl7TTW3uF/4W8gIitPv2S/Sy0tGVOq/8eeO5VLw+n7eDQhTTfV1K
o2dTEWEeYpIvInTKzhBsD4mbv+9s/HHvJ7BYYw==
-----END CERTIFICATE----- -----BEGIN CERTIFICATE-----
MIIDMjCCAhqgAwIBAgIUSWSn9gNdT/UqWgyqkfKGhK6XE14wDQYJKoZIhvcNAQEL
BQAwFTETMBEGA1UEAxMKZXhtYXBsZS5ydTAeFw0yNDA0MjExOTM0NDdaFw0zNDA0
MTkxOTM1MTdaMBUxEzARBgNVBAMTCmV4bWFwbGUucnUwggEiMA0GCSqGSIb3DQEB
AQUAA4IBDwAwggEKAoIBAQDhaBE0dCdaWlf/I+RPX9d1kBN6r/TOmgxXh7sDvlJ7
X8bjgQYzOC5TNseUYWAXiBCNxfcUct1WThXd4kiR3ND6G9dV/Cuu4yk7zn8GS3zj
1Vxj9SmrXN0CtPXDBNrqD1bvFyPqhXWrmOqZ6YuSaTQLZZ3cTTW3McbyWrx9E//v
vKGXfdGKNKJxlcA8zTS1t6B0zOf1ZNhyjFBoKXRfNbA919f9DZjSsExQewzezOMa
nKB1TeCrygzIcLNXlC5lL5t428RG31Hs7HrXDif1xdWGB4WfkWk0I3lGAQt8V9e1
mjhEype6CngBFjltk3zestnCBnG0l+edkPQVuEvUIEiBAgMBAAGjejB4MA4GA1Ud
DwEB/wQEAwIBBjAPBgNVHRMBAf8EBTADAQH/MB0GA1UdDgQWBBQsgNHJ7Oc2d1JU
qwkhD8VCInD4RjAfBgNVHSMEGDAWgBQsgNHJ7Oc2d1JUqwkhD8VCInD4RjAVBgNV
HREEDjAMggpleG1hcGxlLnJ1MA0GCSqGSIb3DQEBCwUAA4IBAQAgp/sGI+KEietN
s8x5o03CJG79AobgNJh7isu7odiJxNhi1CzCRnWbNwNT8e+rUnEvWtRdCYxPLW4r
/sMFfFHy54hZ0GCsBQRzRo1vDhGVs9hjtXBzKq7Zt4ZqW+/eWGcCPklRK9YuJKa5
rBVw+o93JJ0mvjuGgeMHdlBGxm46Ali1VnzS01VFiB/wZvuT0OBJN3XCe35CbsMc
0flYH3+T3hrAOyfrtFwQKO4+75TSTehSZAlzfxXMr9ma+wMcEyF5JzOSMNr/Vyyp
YBlxglA15ibRrJxDyXqgsli5Y0xgiRIbja//kzDJZNzpQsYnqsxvE0BCwaSw1TpL
LtVG9MXE
-----END CERTIFICATE-----]
certificate         -----BEGIN CERTIFICATE-----
MIIDZzCCAk+gAwIBAgIUHtfhNRRYpHzyyYO/HaY4GWxvD3MwDQYJKoZIhvcNAQEL
BQAwLDEqMCgGA1UEAxMhZXhhbXBsZS5ydSBJbnRlcm1lZGlhdGUgQXV0aG9yaXR5
MB4XDTI0MDQyMTIwMDg0M1oXDTI0MDQyMjIwMDkxM1owHDEaMBgGA1UEAxMRZ2l0
bGFiLmV4YW1wbGUucnUwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQC9
dCXLLoeiA/qfPC8IGxmRCAe1FPmmOxsKOlhYb4vAWVv9NJkJHy25/ae64x2toZQd
q8AKg19pMkWQcjrhAU4lGDrSBUrh0Kx46cMM0rGyH24BXDECC6uX09dvym7WeruC
8xIFgqG0FuKA+bPZzXTLUuhvqrfBnxQn0rXLaFcMN2j6PTo1FhdBRyz6mTZ7Npn+
XVlL1Wxl49o8Km+FO0e0LocDyI7kyLXB3svQvWxsM+VUXm7pqDCHIHPkdZbHqdoQ
OCzesQKj53u9aHCochB5V2KQFTQeP/i3seOSumFGBkBaBjLvfBAlOSs/GnFJjvwH
njUgXDhwEs5jPFJQeCuHAgMBAAGjgZAwgY0wDgYDVR0PAQH/BAQDAgOoMB0GA1Ud
JQQWMBQGCCsGAQUFBwMBBggrBgEFBQcDAjAdBgNVHQ4EFgQUow9l9faJG4qt71Yn
MGu3CWXDfvcwHwYDVR0jBBgwFoAUKFCK9XLV4gOaCO9PkMRI1uLN/1MwHAYDVR0R
BBUwE4IRZ2l0bGFiLmV4YW1wbGUucnUwDQYJKoZIhvcNAQELBQADggEBABJKAGZm
oknLHxIiyGF/8s1dQUTd5LiMLKNkZkLwcy5Mr86BfVwIbraRXscQ1dH2DKwJ8ivu
5VVeNkT9XA8ymMSeNHNQW+IVSRuSixcqPHMc6JPHP+h5XRu0zruZ6TAf3udZGcuU
V/1NBF3bBdXWHT2d+i3B2QyjHntYFRizp39NDDxZXnc5gk8CLxmdx1ABOgQoyg7R
nPgX7n/UDOdQZ+B9JNOZr2Do2+0OLDLfOElkc0edScDnOqxCg04vtp8KITj/AucA
YoM/zQPfe91gRrmjlhCE/bENmxC9ojqF+w4F29mSIdc9VO62lBB/XfOwO/AUETKp
Bx5ePSTPXxjuVkc=
-----END CERTIFICATE-----
expiration          1713816553
issuing_ca          -----BEGIN CERTIFICATE-----
MIIDqDCCApCgAwIBAgIUY3OJANBaAFGaBskZypYvltS8XLYwDQYJKoZIhvcNAQEL
BQAwFTETMBEGA1UEAxMKZXhtYXBsZS5ydTAeFw0yNDA0MjEyMDAwMDVaFw0yOTA0
MjAyMDAwMzVaMCwxKjAoBgNVBAMTIWV4YW1wbGUucnUgSW50ZXJtZWRpYXRlIEF1
dGhvcml0eTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAJKXrw3bA/Rh
PvNpoxMHzmy/5ucABFQGOqRbTE1o44zGLsDAnNk3bLnWsP68ut8WsNWAUCox/tWf
L9nFZxO0zIS537gNDP3Vqq2IeMWPjGK4eR7emVjZXsFlW80wwrsTrgv/jlc1NKHH
z9trP4Lpv+ci8UrvLYEr9dQKvQDXnK9/UlsRtroFbYVMzVl1rgdXy+gt7axfFq7x
NVvkLc4O1uvXFPIEfpqHU1eCpnoDOLTaAcIwG3fQx5WmwCmLARecE1Kgf7sp9Ejz
jCYElcPEwt9AkKHq8/YOSoheRUGiNl5ksvQZrpIyTIXPIxsRFw9jBebaHTZImuav
bHMGhtoGwLECAwEAAaOB2DCB1TAOBgNVHQ8BAf8EBAMCAQYwDwYDVR0TAQH/BAUw
AwEB/zAdBgNVHQ4EFgQUKFCK9XLV4gOaCO9PkMRI1uLN/1MwHwYDVR0jBBgwFoAU
LIDRyeznNndSVKsJIQ/FQiJw+EYwPQYIKwYBBQUHAQEEMTAvMC0GCCsGAQUFBzAC
hiFodHRwOi8vdmF1bHQudmF1bHQ6ODIwMC92MS9wa2kvY2EwMwYDVR0fBCwwKjAo
oCagJIYiaHR0cDovL3ZhdWx0LnZhdWx0OjgyMDAvdjEvcGtpL2NybDANBgkqhkiG
9w0BAQsFAAOCAQEAQI/v31vqlTkT9no7t62V6hvL8LPTMV/OIEM+YHoVV+SPF4m/
P0TxHz0XK7U0O71EMWRv+PT8xDx/PE50bVeFyNARUBz4njKDJgtY2DOFA4UtZuFi
pSheMeZDccRQLJWsXhob6vXa2SHzNv1V0EN59OSAttbT1YA/L12oKgklfyoTZTbv
KTtDzxVdJCq646j7S9e7nRUmf6uBsNewIJGPv+fwo89KNJRGrV9+xI5YhA5ktRN2
cv3Cahwd9ZfVPl7TTW3uF/4W8gIitPv2S/Sy0tGVOq/8eeO5VLw+n7eDQhTTfV1K
o2dTEWEeYpIvInTKzhBsD4mbv+9s/HHvJ7BYYw==
-----END CERTIFICATE-----
private_key         -----BEGIN RSA PRIVATE KEY-----
MIIEogIBAAKCAQEAvXQlyy6HogP6nzwvCBsZkQgHtRT5pjsbCjpYWG+LwFlb/TSZ
CR8tuf2nuuMdraGUHavACoNfaTJFkHI64QFOJRg60gVK4dCseOnDDNKxsh9uAVwx
Agurl9PXb8pu1nq7gvMSBYKhtBbigPmz2c10y1Lob6q3wZ8UJ9K1y2hXDDdo+j06
NRYXQUcs+pk2ezaZ/l1ZS9VsZePaPCpvhTtHtC6HA8iO5Mi1wd7L0L1sbDPlVF5u
6agwhyBz5HWWx6naEDgs3rECo+d7vWhwqHIQeVdikBU0Hj/4t7HjkrphRgZAWgYy
73wQJTkrPxpxSY78B541IFw4cBLOYzxSUHgrhwIDAQABAoIBAFnPocr8N9gaQskR
4snY7vnN8LlrRB4Fjv/+QLtLxdhdhDo4oQOuACNXmBgEaqFRI8IdFWDmfmiEKG4d
eMQJtl3napr9X05Fej2ns4t0pkBmneOPLLxng+TpzAt2z6xlalbdnAF4t+eDocS6
mwP5XhC1MPMe3xWusANg5EWVJQ7os8pvXQh/QyvA0Awx1KxoXWGBujDv5wr49ZAo
ARnSmIv7q3NRqsOhyryAirH+Y03ytKzMKdAypLnl6BDi5zPlJFxVz+IiICFS6EXw
psHU/sSgpld8zaXDsOfm02Im8++47TWwN5oMSqEv6yWath+5miThTdRMB2CgBOmp
lswtxmECgYEA8zVLzletXufx+Z9dhkq0gxiDdpOJuuiulwZHEnT38NtkRy6RWF6r
q2tNetiHZvAt6XzdVbJ2WkPjMYZ8Z0OPDu3beoci0z8DKHm9FMFmmtdiW42BWjxl
FivrC2I/pgFZh8yJKMZTTFAdm89jQX3J4GQpuYCs7AJno2pFaCQg7CUCgYEAx2sR
dnqomWhc2VWdTvjc+nAgIDOEBaUnz3qYw8jf0Eh040G17UaxoyeSm7wduB/qq9oi
WZ3LlmotICoix8SavfAla8Zy+XnlM7b0p/yR1RJBqvOnWqK5xWmqVwtQdarxPKro
8KGQFr9dtUt6LhhOI9uoAox0K8rq1XXlJUF/EzsCgYB4dZFSZkLMmv1SsghUl3PI
6r9SX8j79nti+g0Bq0WS2ldUmlALAPjuMntxuQV3isZyuxG1fGr6Ul2ZDg9X5jJZ
Jp5qlbw9/RvHVGS+fvwe/UcOKYxD8V3wGViVjtgPlOOPS1M0Cub/CT9hCNsUeQUg
SvwPkRgU3SwP2HcAGcTksQKBgE2NfwITm6PlaU6ANCg1MkMW/fdn8Wz8mKngpK5n
XVs0Ankq4eR//K9VwXddRjWH/AyPTZKKglVhv2Dl4hbMh91cGkF6sNYCqLde7HC0
EcbKTc186lWeOR7kBAHL/aN1MlIEqYiDXHTsQTYzPzXT7/eUAhfTpY4uYPtY2R+P
BCtnAoGAcDu1uGO7fV2mybolpRtbnhMJZbkppdkk1JW5eEqqmelJOf7E6PiMcFmx
329CoxNXBmytKFHnW06a99CRu6VSpsVYuauIEhvxafFBBroW6+JnRepdNxPc9/Fc
Jg+wTsdsujJjr3zRK9U+oKLLMB2WGk8i5J4cI7zRR2oAENKZo5w=
-----END RSA PRIVATE KEY-----
private_key_type    rsa
serial_number       1e:d7:e1:35:14:58:a4:7c:f2:c9:83:bf:1d:a6:38:19:6c:6f:0f:73


# kubectl exec -it -n vault vault-0 -- vault write pki_int/revoke serial_number="1e:d7:e1:35:14:58:a4:7c:f2:c9:83:bf:1d:a6:38:19:6c:6f:0f:73"
Key                        Value
---                        -----
revocation_time            1713730258
revocation_time_rfc3339    2024-04-21T20:10:58.972708119Z
state                      revoked