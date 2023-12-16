# AlexClev_platform
В манифест web-pod.yml добвалены проверки readinessProbe и livenessProbe. Проверен запуск пода, получены ошибки из-за некорретного порта
Проверден поиск информаии по корректности проверки livenessProbe на базе поиска процесса. Предполагаю, что проверка не имеет смыслА, как как работающий процесс не гарантирует работу сервиса. Возможно, способ применим , если другие виды проверок не подходят, но , теоритичеки, данная проверка ведь работает по умолчанию? Прошу уточнить правильный ответ.
Создан манифест web-deploy.yaml с kind: Deployment и настройками web-pod.yml, при применении также получены ошибки запска под.
После изменения порта и увеличения реплик до 3 единиц поды коректно запустились.
Протестировано развёртывание с различными настройками блока strategy:
maxSurge: 100, maxUnavailable: 0 - Создаются сразу все  новые поды,  по мере готовности старые  удаляются
maxSurge: 0, maxUnavailable: 100 - сначала удаляются все старые поды, псоздаются разом все новые 
maxSurge: 0, maxUnavailable: 0  -получена ошибка, так как мы убираем возможность любого манёвра
maxSurge: 100, maxUnavailable: 100 - Создаются сразу все  новые поды,  старые удаляются сразу же
Создан манифест web-svc-cip.yaml и развернут сервис c типом Cluster IP
Произведена настройка и включение IPSV через перезапуск minikube c параметрами: minikube start --addons=metallb --extra-config kube-proxy.mode=ipvs --extra-config kube-proxy.ipvs.strictARP=true и настрокой kube-proxy через kubectl --namespace kube-system edit configmap/kube-proxy:
kubectl logs kube-proxy-d8dqw  -n kube-system | grep "Using ipvs Proxier"
I1122 17:45:21.221481       1 server_others.go:218] "Using ipvs Proxier"
Однако сделать подключение не удалось, исходя из найденных описаний из-за используемлй платформы (виртуалка VMWare и minikube с драйвером docker)
Установлен MetalLB. В методичке ссылка некорректная, установлен с использованием манифеста по адресу https://raw.githubusercontent.com/metallb/metallb/v0.13.12/config/manifests/metallb-native.yaml
Настроен балансировщик через манифест metallb-config.yaml и запущен новый сервис через манифест web-svc-lb.yaml
После добавления статического маршрута через route add -net 172.17.255.0/24 gw 192.168.49.2 к сервису получен доступ:
$ kubectl --namespace metallb-system logs controller-7f75d4cbfb-hlxb4 | grep web-svc-lb | grep ip
{"caller":"service.go:114","event":"ipAllocated","ip":"172.17.255.1","msg":"IP address assigned by controller","service":"default/web-svc-lb","ts":"2023-11-22T18:16:08.362379078Z"}
$ curl -s http://172.17.255.1/index.html | head -5
<html>
<head/>
<body>
<!-- IMAGE BEGINS HERE -->
<font size="-3">

Настроен сервис LoadBalancer для доступа к CoreDNS через coredns-svc-lb.yaml:
$ kubectl get svc kube-dns -o wide -n  kube-system
NAME       TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)                  AGE   SELECTOR
kube-dns   ClusterIP   10.96.0.10   <none>        53/UDP,53/TCP,9153/TCP   12d   k8s-app=kube-dns

$ host web-svc-lb.default.svc.cluster.local 172.17.255.2
Using domain server:
Name: 172.17.255.2
Address: 172.17.255.2#53
Aliases:

web-svc-lb.default.svc.cluster.local has address 10.103.193.234

Создан ingress контроллер ingress-nginx и сервис-прокси через манифест nginx-lb.yaml
Создан сервис без адреса через манифест web-svc-headless.yaml
Произведена настрока ингресс-прокси. По указанному в методичке манифесту web-ingress.yaml ничего не заработало  В связи с чем был подготовлен новый манифест web-ingress2.yaml на основе документации https://kubernetes.github.io/ingress-nginx/examples/rewrite/
$ kubectl get service ingress-nginx -n ingress-nginx
NAME            TYPE           CLUSTER-IP      EXTERNAL-IP    PORT(S)                      AGE
ingress-nginx   LoadBalancer   10.110.125.23   172.17.255.3   80:31583/TCP,443:32639/TCP   2d1h
otus@otus:/var/homework/network$ curl  -s http://172.17.255.3/web/index.html | head -5
<html>
<head/>
<body>
<!-- IMAGE BEGINS HERE -->
<font size="-3">

Аналогично подготовлен манифест для dashboard kubernetes-dashboard.yaml


Canary для Ingress не тестировался в связи потерей уймы времени на поиск решений из-за неверной информации  в методичке.




 






