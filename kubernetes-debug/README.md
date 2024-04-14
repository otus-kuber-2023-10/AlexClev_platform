Использован существующий кластер на базе minikube
kubectl get nodes
NAME           STATUS     ROLES           AGE   VERSION
minikube       Ready      control-plane   43d   v1.28.3
minikube-m02   NotReady   <none>          32d   v1.28.3

Создадим отдельное простраство и назначим егшо по умолачнию для удобства работы


kubectl create namespace debug
kubectl config set-context --current --namespace=debug

Проверим запуск strace

# strace -c -p1
strace: Could not attach to process. If your uid matches the uid of the target process, check the setting of /proc/sys/kernel/yama/ptrace_scope, or try again as the root user. For more details, see /etc/sysctl.d/10-ptrace.conf: Operation not permitted
strace: attach: ptrace(PTRACE_SEIZE, 1): Operation not permitted

Скачаем kubectl-debug
# wget https://github.com/aylei/kubectl-debug/releases/download/v0.1.1/kubectl-debug_0.1.1_linux_amd64.tar.gz

Распакуем  положим в локацию PATH
# tar -xvf kubectl-debug_0.1.1_linux_amd64.tar.gz
# cp kubectl-debug /home/otus/.local/bin

Проверим:

# kubectl-debug --version
debug version v0.0.0-master+$Format:%h$

Копируем указанный в методичке манифест в файл debug-agent.yml и запускаем

# kubectl apply -f debug-agent.yml
error: resource mapping not found for name: "debug-agent" namespace: "" from "debug-agent.yml": no matches for kind "DaemonSet" in version "extensions/v1beta1"
ensure CRDs are installed first

CRD выложить пожадничали...

Читаем README.md к kubectl-debug и нажодим там ссылку на актуальную версию debug-agent (apiVersion: apps/v1). Ставим её:
# kubectl apply -f https://raw.githubusercontent.com/aylei/kubectl-debug/master/scripts/agent_daemonset.yml
daemonset.apps/debug-agent created

# kubectl get pod -o wide
NAME                READY   STATUS    RESTARTS   AGE   IP             NODE       NOMINATED NODE   READINESS GATES
debug-agent-g89mb   1/1     Running   0          33s   10.244.0.163   minikube   <none>           <none>

Проверим какие у нас есть поды
# get pod -o wide -n default
NAME                        READY   STATUS    RESTARTS       AGE   IP             NODE       NOMINATED NODE   READINESS GATES
nginx-ing-764cf58b9-c5lzh   1/1     Running   12 (44m ago)   42d   10.244.0.143   minikube   <none>           <none>

Отлично, есть вналичии nginx, на нем и  будем эксперементировать:

# kubectl debug -it nginx-ing-764cf58b9-c5lzh -n default --image=nicolaka/netshoot:latest --target=nginx
Targeting container "nginx". If you don't see processes from this container it may be because the container runtime doesn't support this feature.
Defaulting debug container name to debugger-78lfw.
If you don't see a command prompt, try pressing enter.
                    dP            dP                           dP
                    88            88                           88
88d888b. .d8888b. d8888P .d8888b. 88d888b. .d8888b. .d8888b. d8888P
88'  `88 88ooood8   88   Y8ooooo. 88'  `88 88'  `88 88'  `88   88
88    88 88.  ...   88         88 88    88 88.  .88 88.  .88   88
dP    dP `88888P'   dP   `88888P' dP    dP `88888P' `88888P'   dP

Welcome to Netshoot! (github.com/nicolaka/netshoot)
Version: 0.12

 nginx-ing-764cf58b9-c5lzh  ~ 

Проверяем работу strace
# nginx-ing-764cf58b9-c5lzh  ~  strace -p 1 -c
strace: attach: ptrace(PTRACE_SEIZE, 1): Operation not permitted

Не работает. Читаем документацию, находим, что по умолчанию используется  Debugging profile "legacy", нам же нужен General, который обеспечивает  capabilities CAP_SYS_PTRACE для возможности вызова ptrace.
Ну раз надо, то запускаем ещё раз с --profile=general

# kubectl debug -it nginx-ing-764cf58b9-c5lzh -n default --image=nicolaka/netshoot:latest --target=nginx --profile=general

В этот раз сработало:
# nginx-ing-764cf58b9-c5lzh  ~  strace -p 1 -c
strace: Process 1 attached

Смотрим процессы:
# nginx-ing-764cf58b9-c5lzh  ~  ps ax
PID   USER     TIME  COMMAND
    1 root      0:00 nginx: master process nginx -g daemon off;
   20 bird      0:00 nginx: worker process
   21 bird      0:00 nginx: worker process
  100 root      0:01 zsh
  179 root      0:00 ps ax


В соседней консоли подключаемся к миникубу и смотрим контейнеры 
docker ps | grep k8s_debugger
17caed8f86a7   nicolaka/netshoot           "zsh"                    26 minutes ago      Up 26 minutes  k8s_debugger-p2jbw_nginx-ing-764cf58b9-c5lzh_default_9a9ed1be-a233-4d79-ae19-4f688f3cbf21_0

Проверяем права у этого контейнера:
docker inspect 17caed8f86a7 | grep "CapAdd" -A 2
            "CapAdd": [
                "SYS_PTRACE"
            ],


Переходим к работе с iptables-tailer

Смотрим как нам использовать Calico  https://docs.tigera.io/calico/latest/getting-started/kubernetes/minikube
Выбираем предустановленный вариант, для ччерез перезапускаем minikube c опцией --network-plugin=cni --cni=calico

Указанный в методичке netperf-operator уже 5 лет как не поддерживается и ставить его нецелесообразно, всё равно не работает. Из альтернативного попалася проект k8s-netperf , с ним и попробуем протестироваться

Ставим:
# git clone http://github.com/cloud-bulldozer/k8s-netperf
# apt install -y make golang
# cd k8s-netperf && make build
# kubectl create ns netperf
# kubectl create sa -n netperf netperf

В этот момент вирутальная машина умерла, поэтому создал кластер в яндекс облаке со включенной политикой Calico

kubectl get nodes -o wide
NAME                        STATUS   ROLES    AGE   VERSION   INTERNAL-IP   EXTERNAL-IP     OS-IMAGE             KERNEL-VERSION      CONTAINER-RUNTIME
cl1g0lr56jbhjkbp3dn9-arid   Ready    <none>   42m   v1.26.2   10.129.0.38   158.160.12.56   Ubuntu 20.04.6 LTS   5.4.0-167-generic   containerd://1.6.22
cl1g0lr56jbhjkbp3dn9-ybop   Ready    <none>   34m   v1.26.2   10.129.0.22   158.160.78.52   Ubuntu 20.04.6 LTS   5.4.0-167-generic   containerd://1.6.22

Подключимся к первой ноди установим k8s-netperf

# git clone http://github.com/cloud-bulldozer/k8s-netperf
# cd k8s-netperf
# make build


Создадим требуемые пространства и учётку: 
# kubectl create ns netperf
# kubectl create sa netperf -n netperf

настьраиваем на ноде доступ к кластеру и пробем запустить тест

# ./bin/amd64/k8s-netperf --tcp-tolerance 1
INFO[2024-04-08 18:25:53] Starting k8s-netperf (main@4420fb8d27dfbc3c4b967302de8f3868023423a2)
INFO[2024-04-08 18:25:53] 📒 Reading netperf.yml file.
INFO[2024-04-08 18:25:53] 📒 Reading netperf.yml file - using ConfigV2 Method.
INFO[2024-04-08 18:25:53] Cleaning resources created by k8s-netperf
INFO[2024-04-08 18:25:54] ⏰ Waiting for client Deployment to deleted...
ERRO[2024-04-08 18:25:54] Node count too low to run pod to pod across nodes.

Нод маловато для теста. ок, добавим ещё одну в кластер
 kubectl get nodes -o wide
NAME                        STATUS     ROLES    AGE     VERSION   INTERNAL-IP   EXTERNAL-IP      OS-IMAGE             KERNEL-VERSION      CONTAINER-RUNTIME
cl1g0lr56jbhjkbp3dn9-arid   Ready      <none>   5d      v1.26.2   10.129.0.38   51.250.103.109   Ubuntu 20.04.6 LTS   5.4.0-167-generic   containerd://1.6.22
cl1g0lr56jbhjkbp3dn9-egyr   Ready      <none>   4s      v1.26.2   10.129.0.35   84.201.161.82    Ubuntu 20.04.6 LTS   5.4.0-167-generic   containerd://1.6.22
cl1g0lr56jbhjkbp3dn9-ybop   Ready      <none>   4d23h   v1.26.2   10.129.0.22   51.250.23.160    Ubuntu 20.04.6 LTS   5.4.0-167-generic   containerd://1.6.22


Пробуем повторно -тот же результат

Визможно,  это вообще в Яндекс облаке не работает - достоверной инфомации нет, а время поджимает. Возвращаемся к исходному варианту. 
Создаём новую виртуалку на Ubuntu и ставим локальный кластер на старой версии kind  - по найденной информации с netperf-operator должен работать в версии до 1.21

# kind create cluster --name clusterdebag --image kindest/node:v1.19.16 --config kind-config.yaml
# kubectl apply -f https://docs.projectcalico.org/v3.8/manifests/calico.yaml
# kubectl -n kube-system set env daemonset/calico-node FELIX_IGNORELOOSERPF=true
# kubectl apply -f https://raw.githubusercontent.com/piontec/netperf-operator/master/deploy/crd.yaml
# kubectl apply -f https://raw.githubusercontent.com/piontec/netperf-operator/master/deploy/rbac.yaml
# kubectl apply -f https://raw.githubusercontent.com/piontec/netperf-operator/master/deploy/operator.yaml
deployment.apps/netperf-operator created
В этот раз работает, отлично.

Применяем манифест Cr
# kubectl apply -f https://raw.githubusercontent.com/piontec/netperf-operator/master/deploy/cr.yaml

Проверяем:
# kubectl describe netperf.app.example.com/example
Name:         example
Namespace:    default
Labels:       <none>
Annotations:  <none>
API Version:  app.example.com/v1alpha1
Kind:         Netperf
Metadata:
  Creation Timestamp:  2024-04-14T17:02:50Z
  Generation:          4
  Resource Version:    2424
  Self Link:           /apis/app.example.com/v1alpha1/namespaces/default/netperfs/example
  UID:                 052d8087-b9bb-4b05-a54c-b089ab80033a
Spec:
  Client Node:  
  Server Node:  
Status:
  Client Pod:          netperf-client-b089ab80033a
  Server Pod:          netperf-server-b089ab80033a
  Speed Bits Per Sec:  6727.45
  Status:              Done

Видим "Status: Done", идём дальше и добавляем политику Calico 
# kubectl apply -f https://raw.githubusercontent.com/express42/otus-platform-snippets/master/Module-03/Debugging/netperf-calico-policy.yaml
networkpolicy.crd.projectcalico.org/netperf-calico-policy created

Повторно запускаем тест, видем состояние "Starting"

Проверяем логи:

# iptables --list -nv | grep DROP | grep cali[:]He8TRqGPuUw3VGwk
   66  3960 DROP       all  --  *      *       0.0.0.0/0            0.0.0.0/0            /* cali:He8TRqGPuUw3VGwk */
# iptables --list -nv | grep LOG | grep cali[:]B30DykF1ntLW86eD
   68  4080 LOG        all  --  *      *       0.0.0.0/0            0.0.0.0/0            /* cali:B30DykF1ntLW86eD */ LOG flags 0 level 5 prefix "calico-packet: "
# journalctl -k
-- No entries --


Запускаем iptables-tailer по ссылке из методички
# kubectl apply -f https://raw.githubusercontent.com/express42/otus-platform-snippets/master/Module-03/Debugging/iptables-tailer.yaml

Получаем ошибку. Правим манифест, добавляя seLector и запускем повторно. 
# kubectl apply -f iptables-tailer.yaml
daemonset.apps/kube-iptables-tailer created

Перезапускаем тесты NetPerf 

# kubectl delete  netperfs.app.example.com example 
netperf.app.example.com "example" deleted
# kubectl apply -f https://raw.githubusercontent.com/piontec/netperf-operator/master/deploy/cr.yaml
netperf.app.example.com/example created
# kubectl describe netperf.app.example.com/example
Name:         example
Namespace:    default
Labels:       <none>
Annotations:  <none>
API Version:  app.example.com/v1alpha1
Kind:         Netperf
Metadata:
  Creation Timestamp:  2024-04-14T17:41:07Z
  Generation:          4
  Resource Version:    11984
  Self Link:           /apis/app.example.com/v1alpha1/namespaces/default/netperfs/example
  UID:                 bffa79ea-6b4d-44b9-93c6-5d2778c65876
Spec:
  Client Node:  
  Server Node:  
Status:
  Client Pod:          netperf-client-5d2778c65876
  Server Pod:          netperf-server-5d2778c65876
  Speed Bits Per Sec:  0
  Status:              Started test
Events:                <none>

Проверяем логи пода
# kubectl get events -A
default       4m29s       Normal    Created        pod/netperf-server-5d2778c65876   Created container netperf-server-5d2778c65876
default       4m29s       Normal    Started        pod/netperf-server-5d2778c65876   Started container netperf-server-5d2778c65876
kube-system   8m26s       Warning   FailedCreate   daemonset/kube-iptables-tailer    Error creating: pods "kube-iptables-tailer-" is forbidden: error looking up service account kube-system/kube-iptables-tailer: serviceaccount "kube-iptables-tailer" not found
kube-system   63s         Warning   FailedCreate   daemonset/kube-iptables-tailer    Error creating: pods "kube-iptables-tailer-" is forbidden: error looking up service account kube-system/kube-iptables-tailer: serviceaccount "kube-iptables-tailer" not found

Исправляем ошибку с сервсиынм аккаунтом:
# kubectl apply -f https://raw.githubusercontent.com/express42/otus-platform-snippets/master/Module-03/Debugging/kit-serviceaccount.yaml
# kubectl apply -f https://raw.githubusercontent.com/express42/otus-platform-snippets/master/Module-03/Debugging/kit-clusterrole.yaml
# kubectl apply -f https://raw.githubusercontent.com/express42/otus-platform-snippets/master/Module-03/Debugging/kit-clusterrolebinding.yaml
# kubectl delete -n kube-system daemonsets.apps kube-iptables-tailer
daemonset.apps "kube-iptables-tailer" deleted
# kubectl apply -f iptables-tailer.yaml                             
daemonset.apps/kube-iptables-tailer created

Проверяем:
# kubectl get events -A | tail -n 1
kube-system   78s         Normal    SuccessfulCreate   daemonset/kube-iptables-tailer    Created pod: kube-iptables-tailer-6xr5l

Ещё раз перезапускаем тест NetPerf и смотрим логи
# kubectl get events -A
kube-system   57m         Normal    Pulled             pod/kube-iptables-tailer-6xr5l    Successfully pulled image "virtualshuric/kube-iptables-tailer:8d4296a" in 1.089060601s
kube-system   57m         Normal    Pulled             pod/kube-iptables-tailer-6xr5l    Successfully pulled image "virtualshuric/kube-iptables-tailer:8d4296a" in 1.140033877s
kube-system   56m         Normal    Pulled             pod/kube-iptables-tailer-6xr5l    Successfully pulled image "virtualshuric/kube-iptables-tailer:8d4296a" in 1.223761593s
kube-system   58m         Normal    SuccessfulCreate   daemonset/kube-iptables-tailer    Created pod: kube-iptables-tailer-6xr5l

# kubectl describe pod --selector=app=netperf-operator
  Normal  Scheduled  32m   default-scheduler  Successfully assigned default/netperf-server-7697681339b8 to clusterdebag-control-plane
  Normal  Pulled     32m   kubelet            Container image "tailoredcloud/netperf:v2.7" already present on machine
  Normal  Created    32m   kubelet            Created container netperf-server-7697681339b8
  Normal  Started    32m   kubelet            Started container netperf-server-7697681339b8