# AlexClev_platform
 - Установлен и запущен  minikube
 - Оcвоены команды управления pod (get po, delete po, log, describe po)
 - Проверена отказоустойчивость Kubernetes путем попытки удаления контейнеров и pod с системными компонентами
 - Определена причина восстановления pod в kube-system (заданы как static pods minikube, core-dns восстановлен, так как управляется ReplicaSet)
 - Создан web-сервер на базе nginx через dockerfile по требованиям задания
 - Cоздан манифест web-pod.yaml с помощью которого запущен pod с web-сервером
 - Клонирован Hipster Shop, образ размещён в репозитории cleverok2/frontend_demo:0.1 
 - Запущен pod frontend, диагнострирована и устранена ошибка запуска (нехватака переменных окружения)
