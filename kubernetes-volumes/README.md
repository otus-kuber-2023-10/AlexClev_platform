Создан кластер на базе kind
(использование export KUBECONFIG="$(kind get kubeconfig-path --name="kind")" из методички завершилось ошибкой, но на проводимыеработы не повлияло)
Применен манифест рекомендованный minio-statefulset.yaml
Создан headless сервис согласно манифесту minio-headlessservice.yaml
Проверена доступность pod внути кластера и доступность тома.
Созданы и примерены манифесты minio-secrets.yaml и minio-statefulset-secret.yaml для защиты используемых логина и пароля.
По манифесту PersistentVolume.yaml  объявлено хранилище типа hostPath
С помощью манифестов my-pod.yaml и PersistentVolumeClaim.yaml созданный том презентован pod my-pod
На том записаны данные  в файл data.txt после чего том удалён.
Проверено, что в новом поде, созданном с примененим манифеста my-pod2.yaml записанные ранее данные доступны
