Создан кластер на в Яндекс-облаке из 4 нод и 2 пулов:
kubectl get nodes -o wide
NAME                        STATUS   ROLES    AGE   VERSION   INTERNAL-IP   EXTERNAL-IP      OS-IMAGE             KERNEL-VERSION      CONTAINER-RUNTIME
cl182up27l2niqdi4hro-agyk   Ready    <none>   25m   v1.28.2   10.129.0.11   130.193.43.234   Ubuntu 20.04.6 LTS   5.4.0-165-generic   containerd://1.6.22
cl182up27l2niqdi4hro-akob   Ready    <none>   23m   v1.28.2   10.129.0.24   158.160.69.227   Ubuntu 20.04.6 LTS   5.4.0-165-generic   containerd://1.6.22
cl182up27l2niqdi4hro-obop   Ready    <none>   25m   v1.28.2   10.129.0.32   158.160.30.139   Ubuntu 20.04.6 LTS   5.4.0-165-generic   containerd://1.6.22
cl1j8bfh30c7fgna7ohf-ajal   Ready    <none>   11m   v1.28.2   10.129.0.18   84.201.165.216   Ubuntu 20.04.6 LTS   5.4.0-165-generic   containerd://1.6.22

Назначена Taint-политика "node-role=infra:NO_SCHEDULE" узлов пула infra 

Скачиваем и применяем свежий манифест kubernetes-manifests.yaml. Версия образов указана древняя древняя , качаем свежий и ставим заново
kubectl apply -f https://raw.githubusercontent.com/GoogleCloudPlatform/microservices-demo/main/release/kubernetes-manifests.yaml -n microservices-demo

kubectl apply -f kubernetes-manifests.yaml -n microservices-demo
deployment.apps/emailservice created
service/emailservice created
deployment.apps/checkoutservice created
service/checkoutservice created
deployment.apps/recommendationservice created
service/recommendationservice created
deployment.apps/frontend created
service/frontend created
service/frontend-external created
deployment.apps/paymentservice created
service/paymentservice created
deployment.apps/productcatalogservice created
service/productcatalogservice created
deployment.apps/cartservice created
service/cartservice created
deployment.apps/loadgenerator created
deployment.apps/currencyservice created
service/currencyservice created
deployment.apps/shippingservice created
service/shippingservice created
deployment.apps/redis-cart created
service/redis-cart created
deployment.apps/adservice created
service/adservice created

Проверяем 
kubectl get pods -n microservices-demo -o wide
NAME                                     READY   STATUS    RESTARTS   AGE     IP             NODE                        NOMINATED NODE   READINESS GATES
adservice-cf48dc6df-fnhc7                1/1     Running   0          13m     172.16.29.9    cl1j8bfh30c7fgna7ohf-ajal   <none>           <none>
cartservice-657b544cf4-f76sk             1/1     Running   0          13m     172.16.29.14   cl1j8bfh30c7fgna7ohf-ajal   <none>           <none>
checkoutservice-7644b45df9-nkxmt         1/1     Running   0          9m39s   172.16.29.16   cl1j8bfh30c7fgna7ohf-ajal   <none>           <none>
currencyservice-7df78c99-xfsmg           1/1     Running   0          13m     172.16.29.6    cl1j8bfh30c7fgna7ohf-ajal   <none>           <none>
emailservice-5855bdc465-5jltz            1/1     Running   0          9m39s   172.16.29.17   cl1j8bfh30c7fgna7ohf-ajal   <none>           <none>
frontend-695bcc595f-sd5hd                1/1     Running   0          13m     172.16.29.3    cl1j8bfh30c7fgna7ohf-ajal   <none>           <none>
loadgenerator-788d5978c4-9kw9f           1/1     Running   0          13m     172.16.29.8    cl1j8bfh30c7fgna7ohf-ajal   <none>           <none>
paymentservice-57f58b8dc7-w6cwm          1/1     Running   0          13m     172.16.29.10   cl1j8bfh30c7fgna7ohf-ajal   <none>           <none>
productcatalogservice-5b9d97869f-pl575   1/1     Running   0          13m     172.16.29.7    cl1j8bfh30c7fgna7ohf-ajal   <none>           <none>
recommendationservice-7f9cff7b77-qsbrh   1/1     Running   0          13m     172.16.29.5    cl1j8bfh30c7fgna7ohf-ajal   <none>           <none>
redis-cart-bf5c68f69-gjs4t               1/1     Running   0          13m     172.16.29.12   cl1j8bfh30c7fgna7ohf-ajal   <none>           <none>
shippingservice-7556967db5-27vnl         1/1     Running   0          13m     172.16.29.2    cl1j8bfh30c7fgna7ohf-ajal   <none>           <none>

Добавляем репозиторий эластика helm repo add elastic https://helm.elastic.co

Установка по ссылкам из методички, как обычно,  не работает (неудивительно)
 helm upgrade --install elasticsearch elastic/elasticsearch --namespace observability
Release "elasticsearch" does not exist. Installing it now.
Error: failed to fetch https://helm.elastic.co/helm/elasticsearch/elasticsearch-8.5.1.tgz : 403 Forbidden

Скачиваем счерез прокси локально и ставим

helm upgrade --install elasticsearch ./elasticsearch-8.5.1.tar --namespace observability
Release "elasticsearch" does not exist. Installing it now.
NAME: elasticsearch
LAST DEPLOYED: Sat Dec 23 16:40:11 2023
NAMESPACE: observability
STATUS: deployed
REVISION: 1
NOTES:
1. Watch all cluster members come up.
  $ kubectl get pods --namespace=observability -l app=elasticsearch-master -w
2. Retrieve elastic user's password.
  $ kubectl get secrets --namespace=observability elasticsearch-master-credentials -ojsonpath='{.data.password}' | base64 -d
3. Test cluster health using Helm test.
  $ helm --namespace=observability test elasticsearch

Со скачиваением кибаны возникли сложности, ствим через bitnami:
 helm repo add bitnami https://charts.bitnami.com/bitnami
"bitnami" has been added to your repositories
helm repo update bitnami
helm upgrade --install kibana bitnami/kibana --namespace observability

С fluent-bit проблем не возникло, ставим штатно:  helm upgrade --install fluent-bit stable/fluent-bit --namespace observability
Тут же видим WARNING: This chart is deprecated...
Удаляем и ставим свежий
$ helm repo add fluent https://fluent.github.io/helm-charts
$ helm upgrade --install fluent-bit fluent/fluent-bit --namespace observability

Создаём elasticsearch.values.yaml и обновляем эластик  helm upgrade --install elasticsearch ./elasticsearch-8.5.1.tar --namespace observability

kubectl get pods -n observability -o wide -l chart=elasticsearch
NAME                     READY   STATUS    RESTARTS   AGE     IP            NODE                        NOMINATED NODE   READINESS GATES
elasticsearch-master-0   1/1     Running   0          2m51s   172.16.25.4   cl182up27l2niqdi4hro-agyk   <none>           <none>
elasticsearch-master-1   1/1     Running   0          79s     172.16.24.4   cl182up27l2niqdi4hro-obop   <none>           <none>
elasticsearch-master-2   1/1     Running   0          15m     172.16.28.3   cl182up27l2niqdi4hro-akob   <none>           <none>

Ставим ingress

helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx  --namespace=ingress-nginx --create-namespace --wait --values nginx-ingress.values.yaml

kubectl get pods -n ingress-nginx -o wide
NAME                                        READY   STATUS    RESTARTS   AGE   IP            NODE                        NOMINATED NODE   READINESS GATES
ingress-nginx-controller-645b8f9897-26vw5   1/1     Running   0          87s   172.16.28.4   cl182up27l2niqdi4hro-akob   <none>           <none>
ingress-nginx-controller-645b8f9897-rwptl   1/1     Running   0          87s   172.16.24.5   cl182up27l2niqdi4hro-obop   <none>           <none>
ingress-nginx-controller-645b8f9897-xkz4j   1/1     Running   0          87s   172.16.25.5   cl182up27l2niqdi4hro-agyk   <none>           <none>

Создаём kibana.values.yaml, указываем там внешний  адрес сервиса ingress-nginx-controller и обновляем кибану

helm upgrade --install kibana bitnami/kibana --namespace observability --set "elasticsearch.hosts[0]=elasticsearch,elasticsearch.port=9200" -f kibana.values.yaml
Release "kibana" has been upgraded. Happy Helming!
NAME: kibana
LAST DEPLOYED: Thu Jan  4 17:36:33 2024
NAMESPACE: observability
STATUS: deployed
REVISION: 3
TEST SUITE: None
NOTES:
CHART NAME: kibana
CHART VERSION: 10.6.7
APP VERSION: 8.11.3

** Please be patient while the chart is being deployed **

1. Get the application URL by running these commands:
  Get the Kibana URL and associate Kibana hostname to your cluster external IP:

   export CLUSTER_IP=$(minikube ip) # On Minikube. Use: `kubectl cluster-info` on others K8s clusters
   echo "Kibana URL: http://kibana.158.160.135.31.nip.io/"
   echo "$CLUSTER_IP  kibana.158.160.135.31.nip.io" | sudo tee -a /etc/hosts

WARNING: Kibana is externally accessible from the cluster but the dashboard does not contain authentication mechanisms. Make sure you follow the authentication guidelines in your Elastic stack.
+info https://www.elastic.co/guide/en/elasticsearch/reference/current/setting-up-authentication.html

Проверяем доступность кибаны по адресу http://kibana.158.160.135.31.nip.io - кибана недоступна, возможно из-за версий.

Переставляем эластик тоже с  bitnami :

helm upgrade --install elasticsearch bitnami/elasticsearch --namespace observability -f elasticsearch.values.yaml 

Повторно проверяем кибану -теперь всё норм.

Заходим в кибану  в раздел Stack Management -> Index Management -> Indices , обноруживаема отсутствие индексов.

Используя документацию https://docs.fluentbit.io/manual/pipeline/outputs/elasticsearch, готовим манифест для fluent-bit и обновляем его:

helm upgrade --install fluent-bit fluent/fluent-bit --namespace observability -f fluent-bit.values.yaml
Release "fluent-bit" has been upgraded. Happy Helming!
NAME: fluent-bit
LAST DEPLOYED: Thu Jan  4 18:07:23 2024
NAMESPACE: observability
STATUS: deployed
REVISION: 2
NOTES:
Get Fluent Bit build information by running these commands:

export POD_NAME=$(kubectl get pods --namespace observability -l "app.kubernetes.io/name=fluent-bit,app.kubernetes.io/instance=fluent-bit" -o jsonpath="{.items[0].metadata.name}")
kubectl --namespace observability port-forward $POD_NAME 2020:2020

kubectl get pod -n observability -l app.kubernetes.io/instance=fluent-bit -o wide
NAME               READY   STATUS    RESTARTS   AGE     IP             NODE                        NOMINATED NODE   READINESS GATES
fluent-bit-85zhf   1/1     Running   0          7m13s   172.16.25.31   cl182up27l2niqdi4hro-agyk   <none>           <none>
fluent-bit-sbddm   1/1     Running   0          7m13s   172.16.29.10   cl182up27l2niqdi4hro-onus   <none>           <none>
fluent-bit-sj7q5   1/1     Running   0          7m13s   172.16.24.31   cl182up27l2niqdi4hro-obop   <none>           <none>

Проверяем индексы  - появилась группа "fluent-bit"

Устанавливаем оператор прометеуса:
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm upgrade --install prometheus prometheus-community/kube-prometheus-stack -n observability  -f prometheus.values.yaml --wait
Release "prometheus" does not exist. Installing it now.
NAME: prometheus
LAST DEPLOYED: Thu Jan  4 18:35:33 2024
NAMESPACE: observability
STATUS: deployed
REVISION: 1
NOTES:
kube-prometheus-stack has been installed. Check its status by running:
  kubectl --namespace observability get pods -l "release=prometheus"

Visit https://github.com/prometheus-operator/kube-prometheus for instructions on how to create & configure Alertmanager and Prometheus instances using the Operator.

Проверяем доступность http://prometheus.158.160.135.31.nip - ок

Устанавливавем экспортер:
helm upgrade --install elasticsearch-exporter prometheus-community/prometheus-elasticsearch-exporter --set es.uri=http://elasticsearch:9200 --set serviceMonitor.enabled=true -n observability
Release "elasticsearch-exporter" does not exist. Installing it now.
NAME: elasticsearch-exporter
LAST DEPLOYED: Thu Jan  4 19:20:52 2024
NAMESPACE: observability
STATUS: deployed
REVISION: 1
TEST SUITE: None
NOTES:
Get the application URL by running these commands:
export POD_NAME=$(kubectl get pods --namespace observability -l "app=elasticsearch-exporter-prometheus-elasticsearch-exporter" -o jsonpath="{.items[0].metadata.name}")
echo "Visit http://127.0.0.1:9108/metrics to use your application"
kubectl port-forward $POD_NAME 9108:9108 --namespace observability

Импортируем указанный в методичке dashboard ID 4358  в графану

Проверим , что данные соби раются верно, добавив ещё одну мастер-ноду эластика:
helm upgrade --install elasticsearch bitnami/elasticsearch --namespace observability -f elasticsearch.values.yaml --set master.replicaCount=3

Через некоторое время количество нод стало 9 , из них 3 -мастера -всё норм.


Для сбора логов nginx добавляем параметры log-format-escape-json и log-format-upstream в nginx-ingress.values.yaml и пересобираем:
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx  --namespace=ingress-nginx --create-namespace --wait --values nginx-ingress.values.yaml

Настраиваем визуализацию статусов nginx и экспортируем настройки

Ставим локи:
helm repo add grafana https://grafana.github.io/helm-charts
"grafana" has been added to your repositories
helm install loki grafana/loki --namespace observability --values loki.values.yaml
NAME: loki
LAST DEPLOYED: Thu Jan  4 21:28:57 2024
NAMESPACE: observability
STATUS: deployed
REVISION: 1
NOTES:
***********************************************************************
 Welcome to Grafana Loki
 Chart version: 5.41.4
 Loki version: 2.9.3
***********************************************************************

Installed components:
* grafana-agent-operator
* loki

Ставим  promtail:

 helm upgrade --install promtail grafana/promtail -n observability -f promtail.values.yaml
Release "promtail" does not exist. Installing it now.
NAME: promtail
LAST DEPLOYED: Thu Jan  4 21:32:25 2024
NAMESPACE: observability
STATUS: deployed
REVISION: 1
TEST SUITE: None
NOTES:
***********************************************************************
 Welcome to Grafana Promtail
 Chart version: 6.15.3
 Promtail version: 2.9.2
***********************************************************************

Verify the application is working by running these commands:
* kubectl --namespace observability port-forward daemonset/promtail 3101
* curl http://127.0.0.1:3101/metrics


Добавляем в конфигурацию оператора преметуса блок для поключения к локи и обновляем его
  additionalDataSources:
    - name: Loki
      type: loki
      access: proxy
      url: http://loki:3100

занание повыгрузке дащюорда графаны пропускаем, так как метрики , указанные в методичке, устарели.

      
