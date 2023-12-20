Создан кластер на базе minikube
Подготовлен манифест деплоймента для установки 3 реплик пода nginx в комплекте с экспортером.
Создано отдельно пространство под мониторинг  kubectl create namespace monitoring
Конфиг nginx подгружается посредстом configmap: kubectl create configmap nginx-config --from-file=./nginx.conf -n monitoring
Применён манифест, 3 пода создано:
$ kubectl get po -n monitoring
NAME                         READY   STATUS    RESTARTS   AGE
nginx-mon-86979cfd98-gwgr5   2/2     Running   0          10m
nginx-mon-86979cfd98-lc8pv   2/2     Running   0          10m
nginx-mon-86979cfd98-tjxtn   2/2     Running   0          10m

Проверим работу внутри пода:
# curl 127.0.0.1/basic_status
Active connections: 1
server accepts handled requests
 3 3 3
Reading: 0 Writing: 1 Waiting: 0

#  curl 127.0.0.1:9113/metrics
# HELP go_gc_duration_seconds A summary of the pause duration of garbage collection cycles.
# TYPE go_gc_duration_seconds summary
go_gc_duration_seconds{quantile="0"} 0
go_gc_duration_seconds{quantile="0.25"} 0
go_gc_duration_seconds{quantile="0.5"} 0
go_gc_duration_seconds{quantile="0.75"} 0
go_gc_duration_seconds{quantile="1"} 0
go_gc_duration_seconds_sum 0
go_gc_duration_seconds_count 0


Создадим сервис для доступа к подам. Возможно упростить задачу, создав сервис через  kubectl expose deployment/nginx.yml, но поскольку требуется прилижить yaml создаём манифест servicenginx.yml и применяем его 

$ kubectl get endpointslices -l kubernetes.io/service-name=nginx-mon -n monitoring
NAME              ADDRESSTYPE   PORTS     ENDPOINTS                           AGE
nginx-mon-hvwb2   IPv4          80,9113   10.244.0.7,10.244.0.10,10.244.0.8   6m40s

Создаем манифест для ServiceMonitor и получаем ошибку:
$ kubectl apply -f monitoring.yml
error: resource mapping not found for name: "nginx-mon" namespace: "monitoring" from "monitoring.yml": no matches for kind "ServiceMonitor" in version "monitoring.coreos.com/v1"
ensure CRDs are installed first
Выясняем , что ServiceMonitor это часть оператора Prometheus (интересно, зачем давать задание "сделать всё руками", если без оператора его всё равно до конца не сделать?)
Придётся ставить оператор, жаль, диск и так забит мусором:

 kubectl apply -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/main/bundle.yaml

CDR получены, после чего устанваливаем повторно ServiceMonitor:
$ kubectl apply -f monitoring.yml
servicemonitor.monitoring.coreos.com/nginx-mon created


