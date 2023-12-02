Создан кластер на базе kind
Созданы пользователи bob и dave в дефолтном пространстве, выданы права администратора класера для учётной записи bob. Проверен доступ: 
$ kubectl --as=system:serviceaccount:default:bob get pods -n kube-system
NAME                                         READY   STATUS    RESTARTS   AGE
coredns-5d78c9869d-brwjr                     1/1     Running   0          4d20h
coredns-5d78c9869d-qsrgp                     1/1     Running   0          4d20h
etcd-kind-control-plane                      1/1     Running   0          4d20h
kindnet-rcrst                                1/1     Running   0          4d20h
kube-apiserver-kind-control-plane            1/1     Running   0          4d20h
kube-controller-manager-kind-control-plane   1/1     Running   0          4d20h
kube-proxy-vttlv                             1/1     Running   0          4d20h
kube-scheduler-kind-control-plane            1/1     Running   0          4d20h
$  kubectl --as=system:serviceaccount:default:dave get pods -n kube-system
Error from server (Forbidden): pods is forbidden: User "system:serviceaccount:default:dave" cannot list resource "pods" in API group "" in the namespace "kube-system"

Создан namespace prometheus и в нём сервисная запись carol. 
Всем Service Account в namespace prometheus выданы права get , list , watch в отношении Pods всего кластера.
Проверка созданное правило:
$ kubectl describe clusterrolebinding.rbac.authorization.k8s.io pod-prometheus
Name:         pod-prometheus
Labels:       <none>
Annotations:  <none>
Role:
  Kind:  ClusterRole
  Name:  readpod
Subjects:
  Kind   Name                               Namespace
  ----   ----                               ---------
  Group  system:serviceaccounts:prometheus  prometheus

Проверена доступность к под всего кластера и отстуствие доступа в деплойментам:
$ kubectl --as=system:serviceaccount:prometheus:carol get pods -A
NAMESPACE            NAME                                         READY   STATUS    RESTARTS   AGE
default              minio-0                                      1/1     Running   0          4d20h
default              my-pod                                       1/1     Running   0          2d20h
kube-system          coredns-5d78c9869d-brwjr                     1/1     Running   0          4d21h
kube-system          coredns-5d78c9869d-qsrgp                     1/1     Running   0          4d21h
kube-system          etcd-kind-control-plane                      1/1     Running   0          4d21h
kube-system          kindnet-rcrst                                1/1     Running   0          4d21h
kube-system          kube-apiserver-kind-control-plane            1/1     Running   0          4d21h
kube-system          kube-controller-manager-kind-control-plane   1/1     Running   0          4d21h
kube-system          kube-proxy-vttlv                             1/1     Running   0          4d21h
kube-system          kube-scheduler-kind-control-plane            1/1     Running   0          4d21h
local-path-storage   local-path-provisioner-6bc4bddd6b-5hnpl      1/1     Running   0          4d21h

$ kubectl --as=system:serviceaccount:prometheus:carol get deployments -A
Error from server (Forbidden): deployments.apps is forbidden: User "system:serviceaccount:prometheus:carol" cannot list resource "deployments" in API group "apps" at the cluster scope

Создан namespace dev и в нём сервисные записи jane и ken.
В данном пространстве имён jane выдан админский доступ, а ken - только View 

$ kubectl get rolebinding.rbac.authorization.k8s.io -n dev
NAME        ROLE                AGE
dev-admin   ClusterRole/admin   25m
dev-view    ClusterRole/view    25m

$ kubectl describe rolebinding.rbac.authorization.k8s.io -n dev dev-admin
Name:         dev-admin
Labels:       <none>
Annotations:  <none>
Role:
  Kind:  ClusterRole
  Name:  admin
Subjects:
  Kind            Name  Namespace
  ----            ----  ---------
  ServiceAccount  jane  dev

$ kubectl describe rolebinding.rbac.authorization.k8s.io -n dev dev-view
Name:         dev-view
Labels:       <none>
Annotations:  <none>
Role:
  Kind:  ClusterRole
  Name:  view
Subjects:
  Kind            Name  Namespace
  ----            ----  ---------
  ServiceAccount  ken   dev



