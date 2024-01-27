Создан кластер на в Яндекс-облаке из 1 ноды:
kubectl get nodes -o wide
NAME                        STATUS   ROLES    AGE   VERSION   INTERNAL-IP   EXTERNAL-IP      OS-IMAGE             KERNEL-VERSION      CONTAINER-RUNTIME
cl1v3be7c684mjbe5rmj-okal   Ready    <none>   78m   v1.28.2   10.129.0.25   158.160.21.150   Ubuntu 20.04.6 LTS   5.4.0-165-generic   containerd://1.6.22


Установлен nginx-ingress, cert-manager и CRD по методичке

kubectl get pods --namespace cert-manager
NAME                                       READY   STATUS    RESTARTS   AGE
cert-manager-55657857dd-9kzt4              1/1     Running   0          76m
cert-manager-cainjector-7b5b5d4786-mg886   1/1     Running   0          76m
cert-manager-webhook-55fb5c9c88-9j2g7      1/1     Running   0          76m

Создаём объект ClusterIssuer с помощью манифеста acme-issuer.yaml  

Создаем values.yaml и ставим  сhartmuseum:
helm upgrade --install chartmuseum stable/chartmuseum --namespace=chartmuseum --create-namespace -f values.yaml
Release "chartmuseum" does not exist. Installing it now.
WARNING: This chart is deprecated
Error: unable to build kubernetes objects from release manifest: resource mapping not found for name: "chartmuseum-chartmuseum" namespace: "" from "": no matches for kind "Ingress" in version "networking.k8s.io/v1beta1"
ensure CRDs are installed first

Проверяем доступные репозитории:

helm search repo chartmuseum
NAME                    CHART VERSION   APP VERSION     DESCRIPTION
chartmuseum/chartmuseum 3.10.2          0.16.1          Host your own Helm Chart Repository
stable/chartmuseum      2.14.2          0.12.0          DEPRECATED Host your own Helm Chart Repository

Устанвливаем свежую версию с chartmuseum/chartmuseum
helm upgrade --install chartmuseum chartmuseum/chartmuseum --namespace=chartmuseum --create-namespace -f values.yaml
Release "chartmuseum" does not exist. Installing it now.
W0114 17:18:12.065359    2612 warnings.go:70] annotation "kubernetes.io/ingress.class" is deprecated, please use 'spec.ingressClassName' instead
NAME: chartmuseum
LAST DEPLOYED: Sun Jan 14 17:18:11 2024
NAMESPACE: chartmuseum
STATUS: deployed
REVISION: 1
TEST SUITE: None
NOTES:
** Please be patient while the chart is being deployed **

helm ls -n chartmuseum
NAME            NAMESPACE       REVISION        UPDATED                                 STATUS          CHART                   APP VERSION
chartmuseum     chartmuseum     2               2024-01-14 17:31:05.6327212 +0300 MSK   deployed        chartmuseum-3.10.2      0.16.1


Проверяем https://chartmuseum.158.160.142.165.nip.io. Сайт открывается но серт невалиден, выпущен Kubernetes Ingress Controller Fake Certificate, то есть к Let's Encrypt мы не ходим.values.yaml

Проверяем логи

 kubectl get events -A  

 The certificate request has failed to complete and will be retried: Failed to wait for order resource "chartmuseum.tls-1-4167265353" to become ready: order is in "errored" state: Failed to create Order: 429 urn:ietf:params:acme:error:rateLimited: Error creating new order :: too many certificates already issued for "nip.io". Retry after 2024-01-14T21:00:00Z: see https://letsencrypt.org/docs/rate-limits/

 Проверяем на тестовом https://acme-staging-v02.api.letsencrypt.org/directory, создав соответсвующие манифесты и применив их - всё работает.

 По истечении периода блокировки применем основные манифесты acme-issuer.yaml и values.yaml для chartmuseum  : https://chartmuseum.158.160.142.165.nip.io доступен, сертификат валиден.

Добапвим данный ресурс в список репозиьроиев хелма :  helm repo add local_chartmuseum https://chartmuseum.158.160.142.165.nip.io

Проверим работу ресурса. Читаем документацию: https://chartmuseum.com/docs/#uploading-a-chart-package

Разрешим есму работать с API:
helm upgrade --install chartmuseum chartmuseum/chartmuseum --namespace=chartmuseum --create-namespace -f values.yaml --set env.open.DISABLE_API=false

Скачаем Helm chart c https://github.com/goharbor/harbor-helm и соберём его для публикации: helm package .
После чего зальём его в нашё новое хранилище: 
curl -vvv --data-binary @harbor-1.4.0-dev.tgz  https://chartmuseum.158.160.142.165.nip.io/api/charts

*   Trying 158.160.142.165:443...
* Connected to chartmuseum.158.160.142.165.nip.io (158.160.142.165) port 443
* schannel: disabled automatic use of client certificate
* ALPN: curl offers http/1.1
* ALPN: server accepted http/1.1
* using HTTP/1.1
> POST /api/charts HTTP/1.1
> Host: chartmuseum.158.160.142.165.nip.io
> User-Agent: curl/8.4.0
> Accept: */*
> Content-Length: 48918
> Content-Type: application/x-www-form-urlencoded
>
* We are completely uploaded and fine
< HTTP/1.1 201 Created
< Date: Sun, 21 Jan 2024 16:15:14 GMT
< Content-Type: application/json; charset=utf-8
< Content-Length: 14
< Connection: keep-alive
< X-Request-Id: 2dc7a249e80047df495f47d859514fa4
< Strict-Transport-Security: max-age=31536000; includeSubDomains
<
{"saved":true}* Connection #0 to host chartmuseum.158.160.142.165.nip.io left intact

Проверяем получение образа: helm pull local_chartmuseum/harbor --version 1.4.0-dev. Норм. 


По условия задания нужно установить harbor с репозитория https://github.com/goharbor/harbor-helm и CHART VERSION 2.9.0 (на момент выполнения достпна версия 2.10, но задание есть задание)

Добавляем репозиторий: helm repo add harbor https://helm.goharbor.io
Обновляем ведения по репозиториям: helm repo update
Ищим где есть версия 2.9: helm search repo -l harbor

Устанавливаем: helm upgrade --install harbor harbor/harbor -n harbor --create-namespace --version 1.13.0 -f values-harbor.yaml

Проверяем доступность https://harbor.158.160.142.165.nip.io/ - открывется harbor, всё ок

Входим под admin/Harbor12345 -ок

kubectl get secrets -n harbor -l owner=helm
NAME                           TYPE                 DATA   AGE
sh.helm.release.v1.harbor.v1   helm.sh/release.v1   1      7m39s

По методичке инициализируем hipster-shop, удалем файлы, качаем и выкладываем all-hipster-shop.yaml, после чего пробуем установить:

 helm upgrade --install hipster-shop hipster-shop --namespace hipster-shop
Release "hipster-shop" does not exist. Installing it now.
NAME: hipster-shop
LAST DEPLOYED: Fri Jan 26 22:08:02 2024
NAMESPACE: hipster-shop
STATUS: deployed
REVISION: 1
TEST SUITE: None


helm ls -n hipster-shop
NAME            NAMESPACE       REVISION        UPDATED                                 STATUS          CHART                   APP VERSION
hipster-shop    hipster-shop    1               2024-01-26 22:08:02.2477448 +0300 MSK   deployed        hipster-shop-0.1.0      1.16.0

kubectl -n hipster-shop port-forward service/frontend 8081:80
Forwarding from 127.0.0.1:8081 -> 8080
Forwarding from [::1]:8081 -> 8080
Handling connection for 8081
Handling connection for 8081

Получаем страницу "Uh, oh! Something has failed. Below are some details for debugging..." ну, что есть, технически сайт доступен, хоть и не работает как надо, но это уже не к теме урока.

Генерируем манифесты deployment.yaml, service.yaml, ingress.yaml. Сносим  hipster-shop, ставим фронтенд:

helm upgrade --install frontend frontend --namespace hipster-shop
Проверяем https://shop.158.160.142.165.nip.io/ - видим всё ту же "Uh, oh! Something has failed. Below are some details for debugging...". Ок.


Создаём values.yaml, указываем там tag c новой версией v0.8.0 (вдруг сайт разаботает?), пересобираем и проверяем https://shop.158.160.142.165.nip.io/ - ничего не изменилось

Шаблонизируем другие параметры, указанные в методичке

Добавляем зависимости hipster-shop и обновляем их:
helm dep update hipster-shop

helm dep list hipster-shop
NAME            VERSION REPOSITORY              STATUS
frontend        0.1.0   file://../frontend      ok

Проверяем работы "Set" 
helm upgrade --install hipster-shop hipster-shop --namespace hipster-shop --set frontend.service.NodePort=31234

kubectl get svc --namespace hipster-shop
NAME                    TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)        AGE
adservice               ClusterIP   172.16.42.13    <none>        9555/TCP       5m13s
cartservice             ClusterIP   172.16.47.203   <none>        7070/TCP       5m13s
checkoutservice         ClusterIP   172.16.41.0     <none>        5050/TCP       5m13s
currencyservice         ClusterIP   172.16.44.219   <none>        7000/TCP       5m13s
emailservice            ClusterIP   172.16.41.226   <none>        5000/TCP       5m13s
frontend                NodePort    172.16.45.187   <none>        80:31234/TCP   5m13s
paymentservice          ClusterIP   172.16.40.129   <none>        50051/TCP      5m13s
productcatalogservice   ClusterIP   172.16.47.51    <none>        3550/TCP       5m13s
recommendationservice   ClusterIP   172.16.44.160   <none>        8080/TCP       5m13s
redis-cart              ClusterIP   172.16.43.136   <none>        6379/TCP       5m13s
shippingservice         ClusterIP   172.16.41.131   <none>        50051/TCP      5m13s

Порт изменился и соответствует указанному -всё ок

Проверяем логи - видем нехватку памяти ноды для запуска подов, добавляем память, немного ждум и проверяем сайт https://shop.158.160.142.165.nip.io/ - он даже заработал, открылся магазин

Добавляем Redis свежей версии в зависимости и обновляем установку. Проверяем сайт -всё ок


на Secrets, Kubecfg, Kustomize  сил уже не хватило, 6 дней потрачено на ДЗ . 

Формируем  пакеты и закидывавем в harbor
helm package hipster-shop
helm package frontend
helm push ./hipster-shop-0.1.0.tgz oci://harbor.158.160.142.165.nip.io/library
helm push ./frontend-0.1.0.tgz oci://harbor.158.160.142.165.nip.io/library

Создаём repo.sh




