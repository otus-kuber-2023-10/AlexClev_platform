
Поскольку для выполнения задания нужен Gitlib, но в настоящее время ззарегистрироваться на неё невозможно из России, была выделено отдельная виртуальная машина yandex cloud и на ней установлен GitLib. Готовый сервис яндекса не используем протсо из соображений ренировки в ручной установке.
Для создания VM овпользуемся скриптом gitlab.ps1

sudo apt-get update
sudo apt-get install -y curl openssh-server ca-certificates tzdata perl
cd /tmp
curl -LO https://packages.gitlab.com/install/repositories/gitlab/gitlab-ce/script.deb.sh
sudo bash /tmp/script.deb.sh
sudo apt install gitlab-ce
sudo ufw allow http
sudo ufw allow https

Для внешнего доступа используе домен  projectotus.publicvm.com, который регистрировал под курсовую работу

 sudo vi /etc/gitlab/gitlab.rb
 external_url 'https://gitlab.projectotus.publicvm.com'
 
letsencrypt['enable'] = true
letsencrypt['auto_renew'] = true
letsencrypt['contact_emails'] = ['cleverok2012@gmail.com']


sudo gitlab-ctl reconfigure

Смотрим пароль для входа, учётка root
cat /etc/gitlab/initial_root_password | grep Password:
LgjjOKAssZAvfLOXgd1XjQZ/diuLug5Hfg2xLJ2pKSY=
Пароль, соответственно,  меняем, пока действует.

Создаем проект в gitLab microservices-demo 
И копируем туда проект из https://github.com/GoogleCloudPlatform/microservices-demo
git clone https://github.com/GoogleCloudPlatform/microservices-demo
git remote add gitlab https://gitlab.projectotus.publicvm.com/root/microservices-demo.git
git remote -v
gitlab  https://gitlab.projectotus.publicvm.com/root/microservices-demo.git (fetch)
gitlab  https://gitlab.projectotus.publicvm.com/root/microservices-demo.git (push)
git push -uf gitlab main
Enumerating objects: 15510, done.
Counting objects: 100% (15510/15510), done.
Delta compression using up to 8 threads
Compressing objects: 100% (3402/3402), done.
Writing objects: 100% (15510/15510), 33.13 MiB | 8.12 MiB/s, done.
Total 15510 (delta 11911), reused 15508 (delta 11910), pack-reused 0
remote: Resolving deltas: 100% (11911/11911), done.
remote: GitLab: You are not allowed to force push code to a protected branch on this project.
To https://gitlab.projectotus.publicvm.com/root/microservices-demo.git

Снимаем  защиту с основной ветки и публикуем
git push -uf gitlab main
Enumerating objects: 15510, done.
Counting objects: 100% (15510/15510), done.
Delta compression using up to 8 threads
Compressing objects: 100% (3402/3402), done.
Writing objects: 100% (15510/15510), 33.13 MiB | 7.42 MiB/s, done.
Total 15510 (delta 11911), reused 15508 (delta 11910), pack-reused 0
remote: Resolving deltas: 100% (11911/11911), done.
To https://gitlab.projectotus.publicvm.com/root/microservices-demo.git
 + 7fe6f46...6960a23 main -> main (forced update)
branch 'main' set up to track 'gitlab/main'.

Настроем runner для github и соберем на нем образы миркосервисов. Для этого подготовим шаблон сборки образа build_push_image.yml и pipeline gitlab  .gitlab-ci.yml
При этом использовать в качестве тэга $CI_COMMIT_TAG не получилось, так как переменная всегда почему-то получает пустое значение. Использован тэг v0.0.1
Поскольку заливать образы будем в Docker Hub, заполняем переменные для проекта CI_REGISTRY, CI_REGISTRY_IMAGE, CI_REGISTRY_PASSWORD,  CI_REGISTRY_USER и запускаем pipeline

Running with gitlab-runner 16.11.0 (91a27b2a)
  on gitops_shell cXPyxnyvJ, system ID: s_47a0d5c941a3
Preparing the "shell" executor
00:00
Using Shell (bash) executor...
Preparing environment
00:00
Running on epdjgem5c6rcnfhb9gka...
Getting source from Git repository
00:01
Fetching changes with git depth set to 20...
Reinitialized existing Git repository in /home/yc-user/builds/cXPyxnyvJ/0/root/microservices-demo/.git/
Checking out 2e4e1b3d as detached HEAD (ref is main)...
Skipping Git submodules setup
Executing "step_script" stage of the job script
01:26
$ cd $CI_PROJECT_DIR/$DIR
$ echo $CI_REGISTRY_PASSWORD | docker login  $CI_REGISTRY -u $CI_REGISTRY_USER --password-stdin
WARNING! Your password will be stored unencrypted in /root/.docker/config.json.
Configure a credential helper to remove this warning. See
https://docs.docker.com/engine/reference/commandline/login/#credentials-store
Login Succeeded
$ docker build -t $IMAGE_TAG .
DEPRECATED: The legacy builder is deprecated and will be removed in a future release.
            Install the buildx component to build images with BuildKit:
            https://docs.docker.com/go/buildx/
Step 1/16 : FROM eclipse-temurin:21@sha256:fe90fc98e067d7708811aec14fa60a4b81127d3dc7387aecc4c446c2c30c1277 as builder
 ---> 737accc869c7
Step 2/16 : WORKDIR /app
 ---> Using cache
 ---> 3560bef86ee1
Step 3/16 : COPY ["build.gradle", "gradlew", "./"]
 ---> Using cache
 ---> 4bccca9b7913
Step 4/16 : COPY gradle gradle
 ---> Using cache
 ---> 352c320f5abd
Step 5/16 : RUN chmod +x gradlew
 ---> Using cache
 ---> 02dfa76c2379
Step 6/16 : RUN ./gradlew downloadRepos
 ---> Using cache
 ---> 9838c1603ef0
Step 7/16 : COPY . .
 ---> Using cache
 ---> dd05b431db05
Step 8/16 : RUN chmod +x gradlew
 ---> Using cache
 ---> 1cb9e78f274f
Step 9/16 : RUN ./gradlew installDist
 ---> Using cache
 ---> eb1fb1ee5f3d
Step 10/16 : FROM eclipse-temurin:21.0.2_13-jre-alpine@sha256:6f78a61a2aa1e6907dda2da3eb791d44ef3d18e36aee1d1bdaa3543bd44cff4b
 ---> d3e9b76faa33
Step 11/16 : RUN apk add --no-cache ca-certificates
 ---> Using cache
 ---> 9f3a1f110e0a
Step 12/16 : RUN mkdir -p /opt/cprof &&     wget -q -O- https://storage.googleapis.com/cloud-profiler/java/latest/profiler_java_agent_alpine.tar.gz     | tar xzv -C /opt/cprof &&     rm -rf profiler_java_agent.tar.gz
 ---> Using cache
 ---> 89dd282150df
Step 13/16 : WORKDIR /app
 ---> Using cache
 ---> d6b8c499dce1
Step 14/16 : COPY --from=builder /app .
 ---> Using cache
 ---> 1f48879c63e0
Step 15/16 : EXPOSE 9555
 ---> Using cache
 ---> d701f138987d
Step 16/16 : ENTRYPOINT ["/app/build/install/hipstershop/bin/AdService"]
 ---> Using cache
 ---> 59f9e11150de
Successfully built 59f9e11150de
Successfully tagged cleverok2/adservice:v0.0.1
$ docker push $IMAGE_TAG
The push refers to repository [docker.io/cleverok2/adservice]
283f6e2eccd4: Preparing
c6b7025401c5: Preparing
9c6a26ed09a4: Preparing
818d5940f7b8: Preparing
56cac6d5495a: Preparing
1c8f94ac5b92: Preparing
3844cbd74837: Preparing
8700812eabac: Preparing
d4fc045c9e3a: Preparing
1c8f94ac5b92: Waiting
3844cbd74837: Waiting
8700812eabac: Waiting
d4fc045c9e3a: Waiting
283f6e2eccd4: Mounted from cleverok2/gitops
56cac6d5495a: Mounted from library/eclipse-temurin
c6b7025401c5: Pushed
818d5940f7b8: Pushed
1c8f94ac5b92: Mounted from library/eclipse-temurin
d4fc045c9e3a: Pushed
9c6a26ed09a4: Pushed
3844cbd74837: Pushed
8700812eabac: Pushed
v0.0.1: digest: sha256:93ea7fcdf0f0b3efb57a98d5ecdf1436996bda9349abf0409ef225349018c282 size: 2203
Cleaning up project directory and file based variables
00:00
Job succeeded

Скопируем helm charts из демонстрционного репозитория и равзмесим из в каталоге deploy/charts.

Для работы будем использовать существующий кластер kubernetes, расширив его до 4 нод.
#  kubectl get nodes
cl1g0lr56jbhjkbp3dn9-omud   Ready    <none>    5m   v1.26.2
cl1g0lr56jbhjkbp3dn9-ucyb   Ready    <none>   12d   v1.26.2
cl1g0lr56jbhjkbp3dn9-ylef   Ready    <none>   12d   v1.26.2
cl1g0lr56jbhjkbp3dn9-yzit   Ready    <none>   12d   v1.26.2


Ставим flux 
curl -s https://fluxcd.io/install.sh | sudo bash

Подключем flux к Gitlab:

flux bootstrap gitlab --hostname gitlab.projectotus.publicvm.com --owner=root --repository=microservices-demo --path=deploy --components-extra=image-reflector-controller,image-automation-controller
► connecting to https://gitlab.projectotus.publicvm.com
► cloning branch "main" from Git repository "https://gitlab.projectotus.publicvm.com/root/microservices-demo.git"
✔ cloned repository
► generating component manifests
✔ generated component manifests
✔ committed component manifests to "main" ("4cdeb68a9a6b7bd5fd173ea463b21fa3fb12addc")
► pushing component manifests to "https://gitlab.projectotus.publicvm.com/root/microservices-demo.git"
► installing components in "flux-system" namespace
✔ installed components
✔ reconciled components
► determining if source secret "flux-system/flux-system" exists
► generating source secret
✔ public key: ecdsa-sha2-nistp384 AAAAE2VjZHNhLXNoYTItbmlzdHAzODQAAAAIbmlzdHAzODQAAABhBLsRCfgMNgo31en53GMcazMAhXT9jjoWPXXAQd9RjIQZinu66HmBbn3zoY5JebApS91lBzEpq6SI1X0n3HHe9lq99ahfQR85o9fy/vHCTSH2Q3nA1IR51SSYZXYy6QDVkg==
✔ configured deploy key "flux-system-main-flux-system-./deploy" for "https://gitlab.projectotus.publicvm.com/root/microservices-demo"
► applying source secret "flux-system/flux-system"
✔ reconciled source secret
► generating sync manifests
✔ generated sync manifests
✔ committed sync manifests to "main" ("bc47b3e7baff0fcf0ae982621673219346799760")
► pushing sync manifests to "https://gitlab.projectotus.publicvm.com/root/microservices-demo.git"
► applying sync manifests
✔ reconciled sync configuration
◎ waiting for GitRepository "flux-system/flux-system" to be reconciled
✔ GitRepository reconciled successfully
◎ waiting for Kustomization "flux-system/flux-system" to be reconciled
✔ Kustomization reconciled successfully
► confirming components are healthy
✔ helm-controller: deployment ready
✔ image-automation-controller: deployment ready
✔ image-reflector-controller: deployment ready
✔ kustomize-controller: deployment ready
✔ notification-controller: deployment ready
✔ source-controller: deployment ready
✔ all components are healthy

Поместим манифест создания namespace microservices-demo в файл deploy/namespaces/microservices-demo.yaml

Проверим, что создался nаmespace:

# kubectl get nаmespace
NAME                 STATUS   AGE
...
microservices-demo   Active   44s
...

# flux get all -A
NAMESPACE       NAME                            REVISION                SUSPENDED       READY   MESSAGE
flux-system     gitrepository/flux-system       main@sha1:b1c78d30      False           True    stored artifact for revision 'main@sha1:b1c78d30'

NAMESPACE       NAME                            REVISION                SUSPENDED       READY   MESSAGE
flux-system     kustomization/flux-system       main@sha1:b1c78d30      False           True    Applied revision: main@sha1:b1c78d30


Создадим HelmRelease frontend.yaml и запушим его в gitlab

Проверяем:

# flux get helmrelease -n microservices-demo
NAME            REVISION        SUSPENDED       READY   MESSAGE
frontend        0.8.1           False           True    Release reconciliation succeeded

# kubectl get helmrelease -n microservices-demo
NAME       AGE    READY   STATUS
frontend   101s   True    Release reconciliation succeeded

# helm list -n microservices-demo
NAME                            NAMESPACE               REVISION        UPDATED                                 STATUS          CHART           APP VERSION
microservices-demo-frontend     microservices-demo      1               2024-05-01 21:54:14.674237307 +0000 UTC deployed     

Зальём его в  Docker Hub microservices-demo с тегом v0.0.2 

$ flux get images repository yandex-hfrog-frontend -n microservices-demo
NAME                    LAST SCAN                       SUSPENDED       READY   MESSAGE
yandex-hfrog-frontend   2024-05-01T22:17:26+03:00       False           True    successful scan: found 2 tags

После изменения названия чарта с frontend на frontend-hipster и версии с 0.8.1 на 0.8.2, обновился helmchart microservices-demo-frontend:
$ flux get sources chart microservices-demo-frontend -n flux-system
NAME                            REVISION        SUSPENDED       READY   MESSAGE
microservices-demo-frontend     0.8.2           False           True    packaged 'frontend-hipster' chart with version '0.8.2'


Установим istio:

# istioctl install --set profile=demo -y
✔ Istio core installed
✔ Istiod installed
✔ Egress gateways installed
✔ Ingress gateways installed
✔ Installation complete
Made this installation the default for injection and validation.

Установим Flagger

# helm repo add flagger https://flagger.app
"flagger" has been added to your repositories

# kubectl apply -f https://raw.githubusercontent.com/fluxcd/flagger/main/artifacts/flagger/crd.yaml
Warning: resource customresourcedefinitions/canaries.flagger.app is missing the kubectl.kubernetes.io/last-applied-configuration annotation which is required by kubectl apply. kubectl apply should only be used on resources created declaratively by either kubectl create --save-config or kubectl apply. The missing annotation will be patched automatically.
customresourcedefinition.apiextensions.k8s.io/canaries.flagger.app configured
Warning: resource customresourcedefinitions/metrictemplates.flagger.app is missing the kubectl.kubernetes.io/last-applied-configuration annotation which is required by kubectl apply. kubectl apply should only be used on resources created declaratively by either kubectl create --save-config or kubectl apply. The missing annotation will be patched automatically.
customresourcedefinition.apiextensions.k8s.io/metrictemplates.flagger.app configured
Warning: resource customresourcedefinitions/alertproviders.flagger.app is missing the kubectl.kubernetes.io/last-applied-configuration annotation which is required by kubectl apply. kubectl apply should only be used on resources created declaratively by either kubectl create --save-config or kubectl apply. The missing annotation will be patched automatically.
customresourcedefinition.apiextensions.k8s.io/alertproviders.flagger.app configured

# helm upgrade -i flagger flagger/flagger --namespace=istio-system --set crd.create=false --set meshProvider=istio --set metricsServer=http://prometheus:9090
Release "flagger" does not exist. Installing it now.

Добавим метку "istio-injection: enabled" в манифест неймспейса microservices-demo 

# kubectl get ns microservices-demo --show-labels
NAME                 STATUS   AGE     LABELS
microservices-demo   Active   2h32m   istio-injection=enabled,kubernetes.io/metadata.name=microservices-demo,kustomize.toolkit.fluxcd.io/name=flux-system,kustomize.toolkit.fluxcd.io/namespace=flux-system

Удалим поды в namespace microservices-demo и проверим что добавился контейнер istio-proxy

# kubectl delete pods --all -n microservices-demo
pod "frontend-8986db7b66-2plqd" deleted
# kubectl describe pod -l app=frontend -n microservices-demo

  istio-proxy:
    Container ID:  containerd://73650aad1deb5880677a63b149d557990c72c0163cc617051387ee4ab59570f3
    Image:         docker.io/istio/proxyv2:1.20.0
    Image ID:      docker.io/istio/proxyv2@sha256:19e8ca96e4f46733a3377fa962cb88cad13a35afddb9139ff795e36237327137
    Port:          15090/TCP
    Host Port:     0/TCP


Создадим манифесты frontend-vs.yaml и frontend-gw.yaml, закинем в гит

# kubectl get -n microservices-demo  gateways.networking.istio.io/frontend
NAME       AGE
frontend   4m1s
Для доступа снаружи нам понадобится EXTERNAL-IP сервиса istio-ingressgateway:

# kubectl get svc istio-ingressgateway -n istio-system
NAME                   TYPE           CLUSTER-IP      EXTERNAL-IP       PORT(S)                                                                      AGE
istio-ingressgateway   LoadBalancer   10.10.10.185   62.84.123.152    15021:31005/TCP,80:31999/TCP,443:32597/TCP,31400:30589/TCP,15443:32392/TCP   42m


Проверим доступ:
# curl http://62.84.123.152

    
<!DOCTYPE html>
<html lang="en">

<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0, shrink-to-fit=no">
    <meta http-equiv="X-UA-Compatible" content="ie=edge">
    <title>
        
        Online Boutique
        
    </title>
..........


Создадим манифест canary.yaml впо методичке, но подправим раздел hosts:

# kubectl get canary -n microservices-demo
NAME       STATUS        WEIGHT   LASTTRANSITIONTIME
frontend   Initialized   0        2024-05-02T18:32:46Z

# kubectl get deployment -n microservices-demo | grep frontend
frontend           0/0     0            0           17h
frontend-primary   1/1     1            1           8m8s

# kubectl get pods -n microservices-demo | grep frontend
frontend-primary-6dddbd98cd-2fpkr   2/2     Running   0          8m21s

Соберём новый образ и проверим канареечный деплой:

# kubectl describe canary frontend -n microservices-demo | tail -15
  Last Transition Time:    2024-05-02T18:50:45Z
  Phase:                   Failed
  Tracked Configs:
Events:
  Type     Reason  Age                    From     Message
  ----     ------  ----                   ----     -------
  Warning  Synced  18m                    flagger  frontend-primary.microservices-demo not ready: waiting for rollout to finish: observed deployment generation less than desired generation
  Normal   Synced  18m (x2 over 18m)      flagger  all the metrics providers are available!
  Normal   Synced  18m                    flagger  Initialization done! frontend.microservices-demo
  Normal   Synced  5m14s                  flagger  New revision detected! Scaling up frontend.microservices-demo
  Normal   Synced  4m44s                  flagger  Starting canary analysis for frontend.microservices-demo
  Normal   Synced  4m44s                  flagger  Advance frontend.microservices-demo canary weight 5
  Warning  Synced  2m14s (x5 over 4m14s)  flagger  Halt advancement no values found for istio metric request-success-rate probably frontend.microservices-demo is not receiving traffic: running query failed: no values found
  Warning  Synced  104s                   flagger  Rolling back frontend.microservices-demo failed checks threshold reached 5
  Warning  Synced  104s                   flagger  Canary failed! Scaling down frontend.microservices-demo

Ошибка.

Добавляем аннотацию обавив аннотацию spec.template.metadata.timestamp в деплоймент frontend и проверим:
# kubectl describe canary frontend -n microservices-demo | tail -15
Events:
  Type     Reason  Age                  From     Message
  ----     ------  ----                 ----     -------
  Normal   Synced  6m37s (x2 over 98m)  flagger  New revision detected! Scaling up frontend.microservices-demo
  Normal   Synced  6m7s (x2 over 98m)   flagger  Starting canary analysis for frontend.microservices-demo
  Normal   Synced  6m7s (x2 over 98m)   flagger  Advance frontend.microservices-demo canary weight 5
  Warning  Synced  5m7s (x7 over 97m)   flagger  Halt advancement no values found for istio metric request-success-rate probably frontend.microservices-demo is not receiving traffic: running query failed: no values found
  Normal   Synced  4m37s                flagger  Advance frontend.microservices-demo canary weight 10
  Warning  Synced  4m7s                 flagger  Halt advancement no values found for istio metric request-duration probably frontend.microservices-demo is not receiving traffic
  Normal   Synced  3m37s                flagger  Advance frontend.microservices-demo canary weight 15
  Normal   Synced  3m7s                 flagger  Advance frontend.microservices-demo canary weight 20
  Normal   Synced  2m37s                flagger  Advance frontend.microservices-demo canary weight 25
  Normal   Synced  2m7s                 flagger  Advance frontend.microservices-demo canary weight 30
  Normal   Synced  97s                  flagger  Copying frontend.microservices-demo template spec to frontend-primary.microservices-demo
  Normal   Synced  37s (x2 over 67s)    flagger  (combined from similar events): Promotion completed! Scaling down frontend.microservices-demo

В этот раз успешно.


# kubectl get canary frontend -n microservices-demo
NAME       STATUS      WEIGHT   LASTTRANSITIONTIME
frontend   Succeeded   0        2023-11-26T11:44:15
