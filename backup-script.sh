#!/bin/bash

# Variables
DATE=$(date +%Y-%m-%d)
HOUR=$(date +%Y-%m-%d_%H:%M:%S)
BACKUPFOLDER="/backups/backup-$DATE"
ZABBIX="yes" # Have you a Zabbix server ? Check Zabbix Config
LOKI="yes" # Have you a LOKI server ? Check LOKI Config
DOCKER="yes" # Have you Docker on this server ?
FOLDERS="/apps" #Folders to backup exept /home and /root
EXECPTFILE=".mkv .tmp"
RETENTION_DAYS=30 # Number of days until object is deleted
SEGMENT_SIZE="256M"

# Swiss Backup Config
type=swift
user=""
key=""
auth=https://swiss-backup02.infomaniak.com/identity/v3
domain=default
tenant=""
tenant_domain=default
region=RegionOne
storage_url=""
auth_version=""


# Zabbix Config
HOSTNAME=""
ZABBIXSERVER=""


# LOKI Config
LOKI_URL=""


# Installation of requirements
function Install-Requirements {
    apt install -y mariadb-client rclone
}




# Connect to Swiss Backup



# Create archives of folders
function Backup-Folders {
    /bin/mkdir $BACKUPFOLDER
    /bin/tar -cjf $BACKUPFOLDER/home-$DATE.tar.bz2 /home
    /bin/tar -cjf $BACKUPFOLDER/root-$DATE.tar.bz2 /root

    if [ "$DOCKER"="yes" ]; then
        /bin/tar -cjf $BACKUPFOLDER/docker-$DATE.tar.bz2 /var/lib/docker 
    fi
}



# Create dump of databases Dockers
function Backup-Database {
    /bin/mkdir -p $BACKUPFOLDER/databases
    CONTAINER_DB=$(docker ps | grep -E 'mariadb|mysql|postgres|-db' | awk '{print $NF}')
    for CONTAINER_NAME in $CONTAINER_DB; do
        echo "[$HOUR]   BackupScript   🌀   Backup database of $CONTAINER_NAME started."
        DB_VERSION=$(docker ps | grep -w $CONTAINER_NAME | awk '{print $2}')

        if [[ $DB_VERSION == *"mariadb"* ]] || [[ $DB_VERSION == *"mysql"* ]]; then
            DB_USER=$(docker exec $CONTAINER_NAME bash -c 'echo "$MYSQL_USER"')
            DB_PASSWORD=$(docker exec $CONTAINER_NAME bash -c 'echo "$MYSQL_PASSWORD"')
            docker exec -e MYSQL_PWD=$DB_PASSWORD $CONTAINER_NAME /usr/bin/mysqldump -u $DB_USER --no-tablespaces --all-databases > "$BACKUPFOLDER"/databases/"$CONTAINER_NAME"-"$DATE".sql
            echo "[$HOUR]   BackupScript   ✅   Backup database of $CONTAINER_NAME completed."
        elif [[ $DB_VERSION == *"postgres"* ]]; then
            DB_USER=$(docker exec $CONTAINER_NAME bash -c 'echo "$POSTGRES_USER"')
            DB_PASSWORD=$(docker exec $CONTAINER_NAME bash -c 'echo "$POSTGRES_PASSWORD"')
            docker exec -t $CONTAINER_NAME pg_dumpall -c -U $DB_USER > "$BACKUPFOLDER"/databases/"$CONTAINER_NAME"-"$DATE".sql
            echo "[$HOUR]   BackupScript   ✅   Backup database of $CONTAINER_NAME completed."
        else
           echo "[$HOUR]   BackupScript   ❌   ERROR : Can't get credentials of $CONTAINER_NAME." 
        fi

        SQLFILE="$BACKUPFOLDER"/databases/"$CONTAINER_NAME"-"$DATE".sql
        SIZE=1000
        if [ "$(du -sb $SQLFILE | awk '{ print $1 }')" -le $SIZE ]; then
            echo "[$HOUR]   BackupScript   ⚠️   WARNING : Backup file of $CONTAINER_NAME is smaller than 1Mo." 
        fi
        
    done
}


# Send to Swiss Backup



# List backups



# Cleanup

DELETE_AFTER=$(( $RETENTION_DAYS * 24 * 60 * 60 ))

# Execution
Backup-Database







