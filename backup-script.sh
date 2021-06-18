#!/bin/bash



# Variables
DATE=$(date +%Y-%m-%d)
WORKFOLDER="/apps/backups"
BACKUPFOLDER="backup-$DATE"
ZABBIX="yes" # Have you a Zabbix server ? Check Zabbix Config
LOKI="yes" # Have you a LOKI server ? Check Loki Config
DICORD="yes" # Do you want Discord Notifications ? Check Discord Config 
DOCKER="no" # Have you Docker on this server ?
FOLDERS="/home /apps" #Folders to backup
EXCLUDE_FOLDERS="$WORKFOLDER /home/debian /apps/data"
EXCLUDE_EXTENSIONS=".mkv .tmp"
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


# Loki Config
LOKI_URL=""

# Discord Config


if [[ $1 =~ "--dry-run" ]]; then
    HOUR=$(date +%Y-%m-%d_%H:%M:%S)
    DRY='echo ['$(date +%Y-%m-%d_%H:%M:%S)']---BackupScript---🚧---DRY RUN : [ '
    DRY2=' ]'
    DRY_RUN="yes"
else
    DRY=""
    DRY2=""
    DRY_RUN="no"
fi


# Installation of requirements
function Install-Requirements {
    apt install -y mariadb-client rclone
}




# Connect to Swiss Backup



# Create archives of folders
function Backup-Folders {
    echo ""
    cd $WORKFOLDER
    $DRY /bin/mkdir $BACKUPFOLDER $DRY2
    if [ -n "$EXCLUDE_FOLDERS" ]; then
        ARG_EXCLUDE_FOLDER=""
        for FOLDEREX in $EXCLUDE_FOLDERS; do
            ARG_EXCLUDE_FOLDER=$(echo $ARG_EXCLUDE_FOLDER "--exclude="$FOLDEREX"" )
        done
    fi

    if [ -n "$EXCLUDE_EXTENSIONS" ]; then
        ARG_EXCLUDE_EXTENSIONS=""
        for EXTENSION in $EXCLUDE_EXTENSIONS; do
            ARG_EXCLUDE_EXTENSIONS=$(echo $ARG_EXCLUDE_EXTENSIONS "--exclude="*$EXTENSION"" )
        done
    fi

    for FOLDER in $FOLDERS; do
        echo ""
        echo "[$(date +%Y-%m-%d_%H:%M:%S)]   BackupScript   🌀   Backup of $FOLDER started."
        #$DRY /bin/tar -cj $ARG_EXCLUDE_FOLDER $ARG_EXCLUDE_EXTENSIONS -f $BACKUPFOLDER/${FOLDER:1}-$DATE.tar.bz2 -C / ${FOLDER:1} $DRY2
        $DRY /bin/tar -c $ARG_EXCLUDE_FOLDER $ARG_EXCLUDE_EXTENSIONS ${FOLDER} -P | pv -s $(du -sb ${FOLDER} | awk '{print $1}') | gzip > $BACKUPFOLDER/${FOLDER:1}-$DATE.tar.gz $DRY2
        echo "[$(date +%Y-%m-%d_%H:%M:%S)]   BackupScript   ✅   Backup of $FOLDER completed."
    done

    if [ "$DOCKER" == "yes" ]; then
        echo "[$(date +%Y-%m-%d_%H:%M:%S)]   BackupScript   🌀   Backup of Docker folders started."
        $DRY /bin/tar -cj $ARG_EXCLUDE_FOLDER $ARG_EXCLUDE_EXTENSIONS -f $BACKUPFOLDER/docker-$DATE.tar.bz2 -C / var/lib/docker $DRY2
        echo "[$(date +%Y-%m-%d_%H:%M:%S)]   BackupScript   ✅   Backup of Docker folders completed."
    fi
}



# Create dump of databases Dockers
function Backup-Database {
    echo ""
    cd $WORKFOLDER
    $DRY /bin/mkdir -p $BACKUPFOLDER/databases $DRY2
    CONTAINER_DB=$(docker ps | grep -E 'mariadb|mysql|postgres|-db' | awk '{print $NF}')
    for CONTAINER_NAME in $CONTAINER_DB; do
        echo ""
        echo "[$(date +%Y-%m-%d_%H:%M:%S)]   BackupScript   🌀   Backup database of $CONTAINER_NAME started."
        DB_VERSION=$(docker ps | grep -w $CONTAINER_NAME | awk '{print $2}')

        if [[ $DB_VERSION == *"mariadb"* ]] || [[ $DB_VERSION == *"mysql"* ]]; then
            DB_USER=$(docker exec $CONTAINER_NAME bash -c 'echo "$MYSQL_USER"')
            DB_PASSWORD=$(docker exec $CONTAINER_NAME bash -c 'echo "$MYSQL_PASSWORD"')
            SQLFILE="$BACKUPFOLDER/databases/$CONTAINER_NAME-$DATE.sql"
            if [[ $DRY_RUN == "yes" ]]; then
                $DRY Execute dump of database in $CONTAINER_NAME $DRY2
            else
                docker exec -e MYSQL_PWD=$DB_PASSWORD $CONTAINER_NAME /usr/bin/mysqldump -u $DB_USER --no-tablespaces --all-databases > $SQLFILE
            fi
            echo "[$(date +%Y-%m-%d_%H:%M:%S)]   BackupScript   ✅   Backup database of $CONTAINER_NAME completed."
        elif [[ $DB_VERSION == *"postgres"* ]]; then
            DB_USER=$(docker exec $CONTAINER_NAME bash -c 'echo "$POSTGRES_USER"')
            DB_PASSWORD=$(docker exec $CONTAINER_NAME bash -c 'echo "$POSTGRES_PASSWORD"')
            SQLFILE="$BACKUPFOLDER/databases/$CONTAINER_NAME-$DATE.sql"
            if [[ $DRY_RUN == "yes" ]]; then
                $DRY Execute dump of database in $CONTAINER_NAME $DRY2
            else
                docker exec -t $CONTAINER_NAME pg_dumpall -c -U $DB_USER > $SQLFILE
            fi
            echo "[$(date +%Y-%m-%d_%H:%M:%S)]   BackupScript   ✅   Backup database of $CONTAINER_NAME completed."
        else
           echo "[$(date +%Y-%m-%d_%H:%M:%S)]   BackupScript   ❌   ERROR : Can't get credentials of $CONTAINER_NAME."
        fi

        SIZE=1000
        if [[ DRY_RUN == "no" ]] && [ "$(du -sb $SQLFILE | awk '{ print $1 }')" -le $SIZE ]; then
            echo "[$(date +%Y-%m-%d_%H:%M:%S)]   BackupScript   ⚠️   WARNING : Backup file of $CONTAINER_NAME is smaller than 1Mo."
        fi

    done
}


# Send to Swiss Backup



# List backups



# Cleanup

DELETE_AFTER=$(( $RETENTION_DAYS * 24 * 60 * 60 ))

# Execution
Backup-Folders
echo ""
printf '=%.0s' {1..100}
echo ""
Backup-Database
