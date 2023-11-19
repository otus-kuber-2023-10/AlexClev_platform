# AlexClev_platform
AlexClev Platform repository
Создан кластер на базе kind
kind create cluster --config kind-config.yaml
Развернут микросервис frontend 
kubectl apply -f frontend-replicaset.yaml
В процессе исходный манифест скорректирован путём добавления секции selector
Произведен скуйлин сервиса через команду kubectl scale replicaset frontend --replicas=3 а также путём корректрировки параметра replicas: 3 в самом манифесте
Проверено восстановление после ручного удаления
kubectl delete pods -l app=frontend | kubectl get pods -l app=frontend -w
Созднан образ с версией 0.0.2 (cleverok2/frontend_demo:v0.0.2), проверено, что  ReplicaSet не обновлет образ  без удаления pod, а только отслеживает их количество
Создан образ сервиса paymentservice в 2 версиях. Версии развёрнуты с помощью ReplicaSet и Deployment
Проверкно, что при использовании Deployment версия образа обновляется, последовательно перезапуская pods
Проверен Deployment Rollback с 3 на 2 версию
kubectl rollout undo deployment paymentservice --to-revision=2 | kubectl get rs -l app=paymentservice

Создана имитация сценария blue-green, когда сначала создаются все новые pod, потому удаляются старые

kubectl apply -f paymentservice-deployment_bg.yaml | kubectl get pods -l app=paymentservice -w
NAME                              READY   STATUS    RESTARTS   AGE
paymentservice-556cdf9b74-gr2jr   1/1     Running   0          4m58s
paymentservice-556cdf9b74-tsf7z   1/1     Running   0          4m23s
paymentservice-556cdf9b74-xx9tf   1/1     Running   0          4m21s
paymentservice-7fff5c6757-rjhj2   0/1     Pending   0          0s
paymentservice-7fff5c6757-q45nw   0/1     Pending   0          0s
paymentservice-7fff5c6757-vzc7j   0/1     Pending   0          0s
paymentservice-7fff5c6757-rjhj2   0/1     Pending   0          0s
paymentservice-7fff5c6757-q45nw   0/1     Pending   0          0s
paymentservice-7fff5c6757-vzc7j   0/1     Pending   0          0s
paymentservice-7fff5c6757-vzc7j   0/1     ContainerCreating   0          0s
paymentservice-7fff5c6757-q45nw   0/1     ContainerCreating   0          0s
paymentservice-7fff5c6757-rjhj2   0/1     ContainerCreating   0          0s
paymentservice-7fff5c6757-rjhj2   1/1     Running             0          1s
paymentservice-7fff5c6757-q45nw   1/1     Running             0          1s
paymentservice-556cdf9b74-gr2jr   1/1     Terminating         0          5m
paymentservice-7fff5c6757-vzc7j   1/1     Running             0          1s
paymentservice-556cdf9b74-tsf7z   1/1     Terminating         0          4m25s
paymentservice-556cdf9b74-xx9tf   1/1     Terminating         0          4m23s

Создана имитация сценария Reverse Rolling Update, когда сначала последовательно по одному создаются новые Pod с поштучным удалением старых

kubectl apply -f paymentservice-deployment_rru.yaml | kubectl get pods -l app=paymentservice -w
NAME                              READY   STATUS    RESTARTS   AGE
paymentservice-7fff5c6757-q45nw   1/1     Running   0          3m37s
paymentservice-7fff5c6757-rjhj2   1/1     Running   0          3m37s
paymentservice-7fff5c6757-vzc7j   1/1     Running   0          3m37s
paymentservice-7fff5c6757-rjhj2   1/1     Terminating   0          3m38s
paymentservice-556cdf9b74-d59lt   0/1     Pending       0          0s
paymentservice-556cdf9b74-d59lt   0/1     Pending       0          0s
paymentservice-556cdf9b74-d59lt   0/1     ContainerCreating   0          0s
paymentservice-556cdf9b74-d59lt   1/1     Running             0          1s
paymentservice-7fff5c6757-vzc7j   1/1     Terminating         0          3m39s
paymentservice-556cdf9b74-fjncv   0/1     Pending             0          0s
paymentservice-556cdf9b74-fjncv   0/1     Pending             0          0s
paymentservice-556cdf9b74-fjncv   0/1     ContainerCreating   0          0s
paymentservice-556cdf9b74-fjncv   1/1     Running             0          1s
paymentservice-7fff5c6757-q45nw   1/1     Terminating         0          3m40s
paymentservice-556cdf9b74-rbt2v   0/1     Pending             0          0s
paymentservice-556cdf9b74-rbt2v   0/1     Pending             0          0s
paymentservice-556cdf9b74-rbt2v   0/1     ContainerCreating   0          0s
paymentservice-556cdf9b74-rbt2v   1/1     Running             0          1s
paymentservice-7fff5c6757-rjhj2   0/1     Terminating         0          4m8s

Создан манифест frontend-deployment.yaml для тестивроания работы readinessProbe. Проверено, что при смене порта или URL pod не запускаются.

Создан манифест nodeexporter-daemonset.yaml для проверки работы DaemonSet. Выполнен запуск манифеста, проверен запуск под на Worker -Нодах и получсение метрик на 9100 порту.
Создана версия nodeexporter-daemonset-all.yaml для работы на всех нодах кластера, путём добавления секции tolerations с указанеим ролей master (по заданию) и control-plane (фактическая роль ноды)


