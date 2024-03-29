Создаем в яндекс облаке отдельное облако c ID b1g2fitjlfgjp12no5tv и сервисный аккаунт в нем с именем svcprod, назначаем права.

генерируем ключ для этого аккаунта:

yc iam key create --service-account-name svcprod --output key_prod.json --folder-id b1g2fitjlfgjp12no5tv

Подготовлен скрипт на Powershell (creare_ya_vm_ssh.ps1) для создания вируальных машин согласно методички, запускаем и создаём:

master - 1 экземпляр (intel ice lake, 2vCPU, 8 GB RAM)
worker - 3 экземпляра (intel ice lake, 2vCPU, 8 GB RAM)

yc compute instance list
+----------------------+--------+---------------+---------+----------------+-------------+
|          ID          |  NAME  |    ZONE ID    | STATUS  |  EXTERNAL IP   | INTERNAL IP |
+----------------------+--------+---------------+---------+----------------+-------------+
| epd2lfq26f8pd7s85m1m | node3  | ru-central1-b | RUNNING | 158.160.85.243 | 10.129.0.33 |
| epd7kna99898kal7131e | node1  | ru-central1-b | RUNNING | 51.250.98.165  | 10.129.0.11 |
| epdj2fjju57vaoei0jhu | node2  | ru-central1-b | RUNNING | 158.160.86.132 | 10.129.0.14 |
| epdr442ajmam0aicdlou | master | ru-central1-b | RUNNING | 51.250.26.11   | 10.129.0.28 |
+----------------------+--------+---------------+---------+----------------+-------------+

Подключаемся к мастер-ноде SSH под пользователем yc-user и запускаем подготовленный скрип по установке ПО согласно методичке, с учётом  произошедших изменений

# sudo ./init_cluster.sh

Инициализируем кластер:
sudo kubeadm init --pod-network-cidr=10.244.0.0/16  --upload-certs --kubernetes-version=v1.28.0 --ignore-preflight-errors=Mem --cri-socket /run/containerd/containerd.sock

Your Kubernetes control-plane has initialized successfully!

To start using your cluster, you need to run the following as a regular user:

  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config

Alternatively, if you are the root user, you can run:

  export KUBECONFIG=/etc/kubernetes/admin.conf

You should now deploy a pod network to the cluster.
Run "kubectl apply -f [podnetwork].yaml" with one of the options listed at:
  https://kubernetes.io/docs/concepts/cluster-administration/addons/

Then you can join any number of worker nodes by running the following on each as root:

# kubeadm join 10.129.0.28:6443 --token da7cub.oxw9ra2rdqr4flon \
        --discovery-token-ca-cert-hash sha256:00c20da2d31ab3ac929e2edf544d5747d003622c296367d50bfc693635b8b503



# kubectl cluster-info
Kubernetes control plane is running at https://10.129.0.28:6443
CoreDNS is running at https://10.129.0.28:6443/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy

To further debug and diagnose cluster problems, use 'kubectl cluster-info dump'.

Выполняем указанные в выводе команды и проверяем состояние кластера: 
# kubectl get nodes
NAME                   STATUS     ROLES           AGE     VERSION
epdq8uj5n9pedn0qrpe5   NotReady   control-plane   2m46s   v1.28.8


Ставим сетевой плагин:
# kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml
namespace/kube-flannel created
clusterrole.rbac.authorization.k8s.io/flannel created
clusterrolebinding.rbac.authorization.k8s.io/flannel created
serviceaccount/flannel created
configmap/kube-flannel-cfg created
daemonset.apps/kube-flannel-ds created

И проверяем ещё раз состояние ноды:

# kubectl get nodes -o wide
NAME                   STATUS   ROLES           AGE     VERSION   INTERNAL-IP   EXTERNAL-IP   OS-IMAGE             KERNEL-VERSION      CONTAINER-RUNTIME
epdq8uj5n9pedn0qrpe5   Ready    control-plane   2m25s   v1.28.8   10.129.0.28   <none>        Ubuntu 20.04.6 LTS   5.4.0-173-generic   containerd://1.7.2

Выполняем скрипт init_cluster.sh на всех нодах и присоединяем их к кластеру
sudo kubeadm join 10.129.0.28:6443 --token da7cub.oxw9ra2rdqr4flon --discovery-token-ca-cert-hash sha256:00c20da2d31ab3ac929e2edf544d5747d003622c296367d50bfc693635b8b503


Получаем ошибку:
[preflight] Running pre-flight checks
error execution phase preflight: couldn't validate the identity of the API Server: could not find a JWS signature in the cluster-info ConfigMap for token ID "da7cub"

Ибо пока настраивали, токен истёк. Генерируем новый :
# kubeadm token create --print-join-command


Пробуем ещё раз -успешно:
# kubectl get nodes -o wide
NAME                   STATUS   ROLES           AGE     VERSION   INTERNAL-IP   EXTERNAL-IP   OS-IMAGE             KERNEL-VERSION      CONTAINER-RUNTIME
epd29uh4enf8ng6f6hfs   Ready    <none>          3m4s    v1.28.8   10.129.0.24   <none>        Ubuntu 20.04.6 LTS   5.4.0-173-generic   containerd://1.7.2
epdc51l0cme8u02n0mbn   Ready    <none>          2m54s   v1.28.8   10.129.0.3    <none>        Ubuntu 20.04.6 LTS   5.4.0-173-generic   containerd://1.7.2
epdq8uj5n9pedn0qrpe5   Ready    control-plane   36m     v1.28.8   10.129.0.28   <none>        Ubuntu 20.04.6 LTS   5.4.0-173-generic   containerd://1.7.2
epduk9irk5bq2viuamvd   Ready    <none>          2m48s   v1.28.8   10.129.0.7    <none>        Ubuntu 20.04.6 LTS   5.4.0-173-generic   containerd://1.7.2


Разворачиваем приложение для эмуляции нагрузки
# kubectl apply -f deploy.yaml
deployment.apps/nginx-deployment created

# kubectl get pods -o wide
NAME                               READY   STATUS    RESTARTS   AGE   IP           NODE                   NOMINATED NODE   READINESS GATES
nginx-deployment-cd5968d5b-4zs2v   1/1     Running   0          56s   10.244.3.2   epduk9irk5bq2viuamvd   <none>           <none>
nginx-deployment-cd5968d5b-7d2cw   1/1     Running   0          56s   10.244.3.3   epduk9irk5bq2viuamvd   <none>           <none>
nginx-deployment-cd5968d5b-dcc2q   1/1     Running   0          56s   10.244.2.2   epdc51l0cme8u02n0mbn   <none>           <none>
nginx-deployment-cd5968d5b-v6v26   1/1     Running   0          56s   10.244.1.2   epd29uh4enf8ng6f6hfs   <none>           <none>

Протестируем обновление кластера

Проверим текущее сосстояние:
# kubectl get nodes
NAME                   STATUS   ROLES           AGE    VERSION
epd29uh4enf8ng6f6hfs   Ready    <none>          4d     v1.28.8
epdc51l0cme8u02n0mbn   Ready    <none>          4d     v1.28.8
epdq8uj5n9pedn0qrpe5   Ready    control-plane   4d1h   v1.28.8
epduk9irk5bq2viuamvd   Ready    <none>          4d     v1.28.8


Смотрим текущую версию kubeadm:
# kubeadm version
# kubeadm version: &version.Info{Major:"1", Minor:"28", GitVersion:"v1.28.8", GitCommit:"fc11ff34c34bc1e6ae6981dc1c7b3faa20b1ac2d", GitTreeState:"clean", BuildDate:"2024-03-15T00:05:37Z", GoVersion:"go1.21.8", Compiler:"gc", Platform:"linux/amd64"}

Проверем, каие версии доступны:
# sudo apt-cache madison kubeadm
   kubeadm | 1.29.3-1.1 | https://pkgs.k8s.io/core:/stable:/v1.29/deb  Packages
   kubeadm | 1.29.2-1.1 | https://pkgs.k8s.io/core:/stable:/v1.29/deb  Packages
   kubeadm | 1.29.1-1.1 | https://pkgs.k8s.io/core:/stable:/v1.29/deb  Packages
   kubeadm | 1.29.0-1.1 | https://pkgs.k8s.io/core:/stable:/v1.29/deb  Packages

Обновимcя до ближайшей, 1.29.0-1.1

Установим требуеюму версию:
# sudo apt-mark unhold kubeadm && sudo apt-get update && sudo apt-get install -y kubeadm='1.29.0-1.1' && sudo apt-mark hold kubeadm

Проверяем
# kubeadm version
# kubeadm version: &version.Info{Major:"1", Minor:"29", GitVersion:"v1.29.0", GitCommit:"3f7a50f38688eb332e2a1b013678c6435d539ae6", GitTreeState:"clean", BuildDate:"2023-12-13T08:50:10Z", GoVersion:"go1.21.5", Compiler:"gc", Platform:"linux/amd64"}

Проверяем возможные обновления:
# sudo kubeadm upgrade plan
Components that must be upgraded manually after you have upgraded the control plane with 'kubeadm upgrade apply':
COMPONENT   CURRENT       TARGET
kubelet     4 x v1.28.8   v1.29.3

Upgrade to the latest stable version:

COMPONENT                 CURRENT    TARGET
kube-apiserver            v1.28.8    v1.29.3sudo kubeadm upgrade apply v1.29.x
kube-controller-manager   v1.28.8    v1.29.3
kube-scheduler            v1.28.8    v1.29.3
kube-proxy                v1.28.8    v1.29.3
CoreDNS                   v1.10.1    v1.11.1
etcd                      3.5.12-0   3.5.10-0

You can now apply the upgrade by executing the following command:

        kubeadm upgrade apply v1.29.3


Предлагется 1.29.3, но мы на это не пойдем. запускаем обновление до 1.29.0-1.1

# sudo kubeadm upgrade apply 1.29.0 -y

[upgrade/successful] SUCCESS! Your cluster was upgraded to "v1.29.0". Enjoy!

[upgrade/kubelet] Now that your control plane is upgraded, please proceed with upgrading your kubelets if you haven't already done so.

 Проверяем результат:
# kubectl get node
NAME                   STATUS   ROLES           AGE    VERSION
epd29uh4enf8ng6f6hfs   Ready    <none>          4d     v1.28.8
epdc51l0cme8u02n0mbn   Ready    <none>          4d     v1.28.8
epdq8uj5n9pedn0qrpe5   Ready    control-plane   4d1h   v1.28.8
epduk9irk5bq2viuamvd   Ready    <none>          4d     v1.28.8

Проверим версию kubectl 
# kubectl version
Client Version: v1.28.8
Kustomize Version: v5.0.4-0.20230601165947-6ce0bf390ce3
Server Version: v1.29.0

Перезапускаем :
# sudo systemctl restart kubelet

 Проверяем повторно:
# kubectl get nodes
NAME                   STATUS   ROLES           AGE    VERSION
epd29uh4enf8ng6f6hfs   Ready    <none>          4d1h   v1.28.8
epdc51l0cme8u02n0mbn   Ready    <none>          4d1h   v1.28.8
epdq8uj5n9pedn0qrpe5   Ready    control-plane   4d1h   v1.28.8
epduk9irk5bq2viuamvd   Ready    <none>          4d1h   v1.28.8

Ничего не изменилось. Проверяем верию API
kubectl describe pod kube-apiserver-epdq8uj5n9pedn0qrpe5  -n kube-system | grep Image
    Image:         registry.k8s.io/kube-apiserver:v1.29.0
    Image ID:      registry.k8s.io/kube-apiserver@sha256:921d9d4cda40bd481283375d39d12b24f51281682ae41f6da47f69cb072643bc

Версия верная.

Проверяем kubelet
# kubelet --version
Kubernetes v1.28.8

А вот тут расхождение.

Проверяем документацию на сайте и смотрим что упущено в методичке, находим, применяем:

# sudo apt-mark unhold kubelet kubectl && sudo apt-get update && sudo apt-get install -y kubelet='1.29.0-1.1' kubectl='1.29.0-1.1' && sudo apt-mark hold kubelet kubectl

# sudo systemctl daemon-reload
# sudo systemctl restart kubelet

Проверяем:

# kubectl get nodes
NAME                   STATUS   ROLES           AGE    VERSION
epd29uh4enf8ng6f6hfs   Ready    <none>          4d1h   v1.28.8
epdc51l0cme8u02n0mbn   Ready    <none>          4d1h   v1.28.8
epdq8uj5n9pedn0qrpe5   Ready    control-plane   4d2h   v1.29.0
epduk9irk5bq2viuamvd   Ready    <none>          4d1h   v1.28.8

Теперь всё отлично.

Займемся нодами. 
Выводи из первую ноду из планирования с игнором daemonsets:
# kubectl drain epd29uh4enf8ng6f6hfs --ignore-daemonsets
node/epd29uh4enf8ng6f6hfs cordoned
Warning: ignoring DaemonSet-managed Pods: kube-flannel/kube-flannel-ds-gkhvt, kube-system/kube-proxy-5rjt6
evicting pod kube-system/coredns-76f75df574-x6c7d
evicting pod default/nginx-deployment-cd5968d5b-v6v26
pod/nginx-deployment-cd5968d5b-v6v26 evicted
pod/coredns-76f75df574-x6c7d evicted
node/epd29uh4enf8ng6f6hfs drained

Проверяем:
# kubectl get nodes
NAME                   STATUS                     ROLES           AGE    VERSION
epd29uh4enf8ng6f6hfs   Ready,SchedulingDisabled   <none>          4d1h   v1.28.8
epdc51l0cme8u02n0mbn   Ready                      <none>          4d1h   v1.28.8
epdq8uj5n9pedn0qrpe5   Ready                      control-plane   4d2h   v1.29.0
epduk9irk5bq2viuamvd   Ready                      <none>          4d1h   v1.28.8


Выполним на данной ноде
# sudo apt-mark unhold kubelet kubectl && sudo apt-get update && sudo apt-get install -y kubeadm='1.29.0-1.1' kubelet='1.29.0-1.1' kubectl='1.29.0-1.1' && sudo apt-mark hold kubelet kubectl
# sudo systemctl daemon-reload
# sudo systemctl restart kubelet
# sudo kubeadm upgrade node

Проверяем наш кластер 

# kubectl get nodes
NAME                   STATUS                     ROLES           AGE    VERSION
epd29uh4enf8ng6f6hfs   Ready,SchedulingDisabled   <none>          4d1h   v1.29.0
epdc51l0cme8u02n0mbn   Ready                      <none>          4d1h   v1.28.8
epdq8uj5n9pedn0qrpe5   Ready                      control-plane   4d2h   v1.29.0
epduk9irk5bq2viuamvd   Ready                      <none>          4d1h   v1.28.8

Отлично, всё успешно.

Возвращаем ноду в строй:
# kubectl uncordon epd29uh4enf8ng6f6hfs
node/epd29uh4enf8ng6f6hfs uncordoned

# kubectl get nodes
NAME                   STATUS   ROLES           AGE    VERSION
epd29uh4enf8ng6f6hfs   Ready    <none>          4d1h   v1.29.0
epdc51l0cme8u02n0mbn   Ready    <none>          4d1h   v1.28.8
epdq8uj5n9pedn0qrpe5   Ready    control-plane   4d2h   v1.29.0
epduk9irk5bq2viuamvd   Ready    <none>          4d1h   v1.28.8


Повтиорим деяния на других нодах и проеврим результат:

NAME                   STATUS   ROLES           AGE    VERSION
epd29uh4enf8ng6f6hfs   Ready    <none>          4d2h   v1.29.0
epdc51l0cme8u02n0mbn   Ready    <none>          4d2h   v1.29.0
epdq8uj5n9pedn0qrpe5   Ready    control-plane   4d2h   v1.29.0
epduk9irk5bq2viuamvd   Ready    <none>          4d2h   v1.29.0

Далее совместим выполнение задания с * и проверку работы с Kubespray

К сожалению, в учебном репозитории нет возможности развернуть кластер через GitHub Action, что значительно упростило бы процесс, поэтому созданим 5 виртуальных машин (master2,master3,master4,node3,node5) с помощью скрипта. Вирутальные машины предыдущего задания ((master1,node1,node2, node3)) остановим: 

yc compute instance list
+----------------------+---------+---------------+---------+----------------+-------------+
|          ID          |  NAME   |    ZONE ID    | STATUS  |  EXTERNAL IP   | INTERNAL IP |
+----------------------+---------+---------------+---------+----------------+-------------+
| epd29uh4enf8ng6f6hfs | node1   | ru-central1-b | STOPPED |                | 10.129.0.24 |
| epd5nc0v20dqsjr931hn | master2 | ru-central1-b | RUNNING | 51.250.21.152  | 10.129.0.11 |
| epdc51l0cme8u02n0mbn | node2   | ru-central1-b | STOPPED |                | 10.129.0.3  |
| epdcdsa11anmj27nfdp1 | master4 | ru-central1-b | RUNNING | 51.250.109.204 | 10.129.0.27 |
| epde36q551hs226batkd | master3 | ru-central1-b | RUNNING | 158.160.20.167 | 10.129.0.10 |
| epdk7al25sv7b4ooegsb | node4   | ru-central1-b | RUNNING | 158.160.16.220 | 10.129.0.30 |
| epdns5mlojpj0mq6g7u1 | node5   | ru-central1-b | RUNNING | 62.84.121.141  | 10.129.0.21 |
| epdq8uj5n9pedn0qrpe5 | master  | ru-central1-b | STOPPED |                | 10.129.0.28 |
| epduk9irk5bq2viuamvd | node3   | ru-central1-b | STOPPED |                | 10.129.0.7  |
+----------------------+---------+---------------+---------+----------------+-------------+
 Обновляем и ставим пакеты (Python нужен не ниже 3.10 из-за чего всё пришлось переделывать, но эту часть опускаем)

sudo apt -y install apt install python3.10-venv
git clone https://github.com/kubernetes-sigs/kubespray.git
VENVDIR=kubespray-venv
KUBESPRAYDIR=kubespray
python3 -m venv $VENVDIR
source $VENVDIR/bin/activate
cd $KUBESPRAYDIR
pip install -U -r requirements.txt

Клонируем инвентори

 cp -rfp inventory/sample inventory/otusprodcluster

И вносим внутренние адреса виртуалок:

cat ~/kubespray/inventory/otusprodcluster/inventory.ini
[all]
master2 ansible_host=10.129.0.17 etcd_member_name=etcd1
master3 ansible_host=10.129.0.27 etcd_member_name=etcd2
master4 ansible_host=10.129.0.12 etcd_member_name=etcd3
node4 ansible_host=10.129.0.15
node5 ansible_host=10.129.0.18

[kube-master]
master2
master3
master4

[etcd]
master2
master3
master4

[kube-node]
node4
node5

[k8s-cluster:children]
kube-master
kube-node


Вносим правильный путь в ansible.cfg к каталогу ролей
roles_path = ~/kubespray/roles

Назначем переменные SSH_USERNAM и SSH_PRIVATE_KEY
export SSH_USERNAME=yc-user
export SSH_PRIVATE_KEY=~/key

Ограничиваем права на приватный ключ: 
chmod 600 ~/key

И запускаем playbook:
 ansible-playbook -i ~/kubespray/inventory/otusprodcluster/inventory.ini --become --become-user=root --user=${SSH_USERNAME} --key-file=${SSH_PRIVATE_KEY} ~/kubespray/cluster.yml

После длительнго ожидания (22 минуты! быстрее руками, а ещё лучше свою роль сделать) отработки плейбука проверям:

kubectl get nodes -o wide
NAME      STATUS   ROLES           AGE   VERSION   INTERNAL-IP   EXTERNAL-IP   OS-IMAGE             KERNEL-VERSION       CONTAINER-RUNTIME
master2   Ready    control-plane   16m   v1.29.3   10.129.0.17   <none>        Ubuntu 22.04.4 LTS   5.15.0-101-generic   containerd://1.7.13
master3   Ready    control-plane   16m   v1.29.3   10.129.0.27   <none>        Ubuntu 22.04.4 LTS   5.15.0-101-generic   containerd://1.7.13
master4   Ready    control-plane   16m   v1.29.3   10.129.0.12   <none>        Ubuntu 22.04.4 LTS   5.15.0-101-generic   containerd://1.7.13
node4     Ready    <none>          15m   v1.29.3   10.129.0.15   <none>        Ubuntu 22.04.4 LTS   5.15.0-101-generic   containerd://1.7.13
node5     Ready    <none>          15m   v1.29.3   10.129.0.18   <none>        Ubuntu 22.04.4 LTS   5.15.0-101-generic   containerd://1.7.13

Задание выполено. 









