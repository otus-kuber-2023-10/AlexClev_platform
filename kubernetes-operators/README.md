# AlexClev_platform
Создан кластер на базе minicube
Создан манифест CRD согласно методичке, получена ошибка 
"The CustomResourceDefinition "mysqls.otus.homework" is invalid: spec.versions[0].schema.openAPIV3Schema: Required value: schemas are required"
Манифест дополнен описанием схему, согласно https://kubernetes.io/docs/tasks/extend-kubernetes/custom-resources/custom-resource-definitions/
При попытке применения Cr.yml получаем ошибку 
Error from server (BadRequest): error when creating "cr.yml": MySQL in version "v1" cannot be handled as a MySQL: strict decoding error: unknown field "spec.database", unknown field "spec.image", unknown field "spec.password", unknown field "spec.storage_size", unknown field "usless_data"
Из чего, помянув добрым словом составителей методички,  делаем вывод, что схема была описана в CDR не полностью и корректруем crd.yml добавлением полей из ошибки и Cr.yml удалением строки с "usless_data"
Успешно применяем оба манифеста
Проверяем взаимодействие с созданными объектами и доходми до раздела Validation ДЗ, где с удивллением обнаруживаем поля, которые нужно было добавить ранее.
Валидацтю пропускаем, так как формат жёстко указан ранее.
Перерыв материалы лекций и не найдя подсказок по описанию обязательный полей в CustomResourceDefinition, снова идём читать документацию
Добавляем строчку в CRD:  required: ["image", "database", "password", "storage_size"]
Установлен python3 и требуемые модули, созданы шаблоны jinja2 и запущен скрипт mysqloperator.py
$ kopf run  mysqloperator.py
/usr/local/lib/python3.10/dist-packages/kopf/_core/reactor/running.py:179: FutureWarning: Absence of either namespaces or cluster-wide flag will become an error soon. For now, switching to the cluster-wide mode for backward compatibility.
  warnings.warn("Absence of either namespaces or cluster-wide flag will become an error soon."
[2023-12-09 18:35:23,667] kopf._core.engines.a [INFO    ] Initial authentication has been initiated.
[2023-12-09 18:35:23,684] kopf.activities.auth [INFO    ] Activity 'login_via_client' succeeded.
[2023-12-09 18:35:23,685] kopf._core.engines.a [INFO    ] Initial authentication has finished.
/var/homework/operators/build/mysqloperator.py:13: YAMLLoadWarning: calling yaml.load() without Loader=... is deprecated, as the default Loader is unsafe. Please read https://msg.pyyaml.org/load for full details.
  json_manifest = yaml.load(yaml_manifest)
[2023-12-09 18:35:24,060] kopf.objects         [INFO    ] [default/mysql-instance] Handler 'mysql_on_create' succeeded.
[2023-12-09 18:35:24,060] kopf.objects         [INFO    ] [default/mysql-instance] Creation is processed: 1 succeeded; 0 failed.
Удаляем ресурсы, созданные контроллером и дополняем скрипт определением дочерний объектов и  обработкой события удаления ресурса mysql, перезапускаем скрипт и прорлучаем новую ошибку:
"NameError: name 'restore_job' is not defined" - понятно, опять ошибка в методичке, правим сами, добавляя раздел с restore_job и запускаем скрипт ещё раз - успех.

Проводим манипудяци с добавлением фрагметов скрипта по удалению Job, запускаем скрипт и снова ловим новую ошибку. Перерыв кучу документации, узнаёю про финализаторы, которые не дают корректно удалить объекты из-за чего происходит конфликт.  Запускаем kubectl get MySQL -A -o yaml, узнаём имена и запускаем kubectl patch MYSQL/mysql-instance -p '{"metadata":{"finalizers":[]}}' --type=merge. После чего снова успех.

Проверяем:
$ kubectl get pvc
NAME                        STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
backup-mysql-instance-pvc   Bound    pvc-03ec9b5e-87e9-4260-9a3c-73bd1b98d215   1Gi        RWO            standard       4m29s
mysql-instance-pvc          Bound    pvc-18e13e69-2810-4d80-894d-c286ceb50cf0   1Gi        RWO            standard       4m29s

Заполняем данными и проверяем:

$ kubectl exec -it $MYSQLPOD -- mysql -potuspassword -e "select * from test;" otus-database
mysql: [Warning] Using a password on the command line interface can be insecure.
+----+-------------+
| id | name        |
+----+-------------+
|  1 | some data   |
|  2 | some data-2 |
+----+-------------+


 





