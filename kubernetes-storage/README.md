Для задания будем использовать стандарнтый кластер на minikube
# kubectl get nodes
NAME       STATUS   ROLES           AGE    VERSION
minikube   Ready    control-plane   5d   v1.28.3

Установим  CSI Host Path драйвер. 
Включаем надстройку на minikube 
# minikube addons enable volumesnapshots
* The 'volumesnapshots' addon is enabled

Установим  CSI Host Path драйвер. Можноиспользовать штатаный
# minikube addons enable csi-hostpath-driver
можно сторонний. Пойдем по сложному пути
# git clone https://github.com/kubernetes-csi/csi-driver-host-path.git
# cd  csi-driver-host-path/deploy/kubernetes-1.28
# ./deploy.sh
applying RBAC rules
curl https://raw.githubusercontent.com/kubernetes-csi/external-provisioner/v4.0.0/deploy/kubernetes/rbac.yaml --output /tmp/tmp.oJpXhl6txD/rbac.yaml --silent                                                                                 --location
kubectl apply --kustomize /tmp/tmp.oJpXhl6txD
serviceaccount/csi-provisioner created
role.rbac.authorization.k8s.io/external-provisioner-cfg created
clusterrole.rbac.authorization.k8s.io/external-provisioner-runner created
rolebinding.rbac.authorization.k8s.io/csi-provisioner-role-cfg created
clusterrolebinding.rbac.authorization.k8s.io/csi-provisioner-role created
curl https://raw.githubusercontent.com/kubernetes-csi/external-attacher/v4.5.0/deploy/kubernetes/rbac.yaml --output /tmp/tmp.oJpXhl6txD/rbac.yaml --silent --                                                                                location
kubectl apply --kustomize /tmp/tmp.oJpXhl6txD
serviceaccount/csi-attacher created
role.rbac.authorization.k8s.io/external-attacher-cfg created
clusterrole.rbac.authorization.k8s.io/external-attacher-runner created
rolebinding.rbac.authorization.k8s.io/csi-attacher-role-cfg created
clusterrolebinding.rbac.authorization.k8s.io/csi-attacher-role created
curl https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/v7.0.1/deploy/kubernetes/csi-snapshotter/rbac-csi-snapshotter.yaml --output /tmp/t                                                                                mp.oJpXhl6txD/rbac.yaml --silent --location
kubectl apply --kustomize /tmp/tmp.oJpXhl6txD
serviceaccount/csi-snapshotter created
role.rbac.authorization.k8s.io/external-snapshotter-leaderelection created
...

Проверим  kubectl get pods
NAME                   READY   STATUS    RESTARTS   AGE
csi-hostpath-socat-0   1/1     Running   0          60s
csi-hostpathplugin-0   8/8     Running   0          62s

# kubectl get pv
NAME         CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM                 STORAGECLASS      REASON   AGE
storage-pv   100M       RWO            Retain           Bound    default/storage-pvc   csi-hostpath-sc            2m32s

#Создадим манифест для PVC и тестового пода и применим:
kubectl apply -f csi.yaml
storageclass.storage.k8s.io/csi-hostpath-sc created
persistentvolumeclaim/storage-pvc created
pod/storage-pod created

# kubectl get pv
NAME                                       CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM                 STORAGECLASS      REASON   AGE
pvc-d6a69db6-4a34-4e46-853c-91d9c08feb58   100M       RWO            Delete           Bound    default/storage-pvc   csi-hostpath-sc            44s

# kubectl get pvc
NAME          STATUS   VOLUME       CAPACITY   ACCESS MODES   STORAGECLASS      AGE
storage-pvc   Bound    pvc-d6a69db6-4a34-4e46-853c-91d9c08feb58   100M       RWO            csi-hostpath-sc   47s

# kubectl get pods
NAME                   READY   STATUS    RESTARTS       AGE
csi-hostpath-socat-0   1/1     Running   0              5m58s
csi-hostpathplugin-0   8/8     Running   1 (4m1s ago)   6m
storage-pod            1/1     Running   0              2m15s

# kubectl describe pod storage-pod | grep Mount -A 2
    Mounts:
      /data from csi-volume (rw)
      /var/run/secrets/kubernetes.io/serviceaccount from kube-api-access-k6hm4 (ro)


Отлично, всё работает: автоматически создался PV и был презентован нашему pod, смонтироан в /data




