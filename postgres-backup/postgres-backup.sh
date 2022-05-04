#!/bin/bash
source backup.config
set -e

backup(){
    cli="kubectl get pod"

    # 1. Get pod by label
    cli="$cli -n $origin_ns"
    for label in "${origin_label[@]}"
    do
        cli="$cli -l $label"
    done
    pod_name=`$cli | tail -1  | cut -d ' ' -f1`
    echo "Pod name = $pod_name"

    # 2. Generate backup.sql file using kubectl exec command
    kubectl exec -n $origin_ns $pod_name -- bash -c "cd /var/lib/postgresql/ && pg_dumpall -U postgres > backup.sql"

    # 3. Copy backup.sql file to local node
    kubectl cp -n $origin_ns $pod_name:/var/lib/postgresql/backup.sql $backup_file_directory/backup.sql
}

restore(){
    cli="kubectl get pod"

    # 1. Get pod by label
    cli="$cli -n $backup_ns"
    for label in "${backup_label[@]}"
    do
        cli="$cli -l $label"
    done
    pod_name=`$cli | tail -1  | cut -d ' ' -f1`
    echo "Pod name = $pod_name"

    # 2. Copy backup.sql file to a container
    kubectl cp -n $backup_ns $backup_file_directory/backup.sql $pod_name:/var/lib/postgresql/backup.sql

    # 3. Execute restore
    kubectl exec -n $backup_ns $pod_name -- bash -c "cd /var/lib/postgresql/ && psql -f backup.sql -U postgres"
}

if [ -z $1 ]
then
    echo "Please give paramater"
    echo "1. backup"
    echo "2. restore"
elif [ $1 == "backup" ]
then
    backup
elif [ $1 == "restore" ]
then
    restore
else
    echo "Unkonwn parameter"
fi