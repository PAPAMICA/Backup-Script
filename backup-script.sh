#!/bin/bash



# Variables
DATE=$(date +%Y-%m-%d)
WORKFOLDER="/apps/backups"
BACKUPFOLDER="backup-$DATE"
ZABBIX="yes" # Have you a Zabbix server ? Check Zabbix Config
LOKI="yes" # Have you a LOKI server ? Check Loki Config
DICORD="yes" # Do you want Discord Notifications ? Check Discord Config 
DOCKER="no" # Have you Docker on this server ?
FOLDERS="/home /var/log" #Folders to backup
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
FOLDER_TOTAL_SIZE=0
FREE_SPACE_H=$(df -h $WORKFOLDER | awk 'FNR==2{print $4}')
FREE_SPACE=$(df $WORKFOLDER | awk 'FNR==2{print $4}')

# Installation of requirements
function Install-Requirements {
    apt install -y mariadb-client rclone pv
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
        FOLDER_SIZE_H=$(du -hs $FOLDER $ARG_EXCLUDE_FOLDER $ARG_EXCLUDE_EXTENSIONS | awk '{print $1}')
        FOLDER_SIZE=$(du -s $FOLDER $ARG_EXCLUDE_FOLDER $ARG_EXCLUDE_EXTENSIONS | awk '{print $1}')
        FOLDER_TOTAL_SIZE=$(echo "$FOLDER_TOTAL_SIZE + $FOLDER_SIZE" | bc)
        echo $FOLDER_TOTAL_SIZE

        echo "[$(date +%Y-%m-%d_%H:%M:%S)]   BackupScript   🌀   Backup of $FOLDER ($FOLDER_SIZE_H) started."
        if [[ $DRY_RUN == "yes" ]]; then
                $DRY "Backup $FOLDER (with $ARG_EXCLUDE_FOLDER and $ARG_EXCLUDE_FOLDER) to $BACKUPFOLDER/${FOLDER:1}-$DATE.tar.gz" $DRY2
            else
                /bin/tar -c $ARG_EXCLUDE_FOLDER $ARG_EXCLUDE_EXTENSIONS ${FOLDER} -P | pv -s $(du -sb ${FOLDER} | awk '{print $1}') | gzip > $BACKUPFOLDER/${FOLDER:1}-$DATE.tar.gz
            fi
        echo "[$(date +%Y-%m-%d_%H:%M:%S)]   BackupScript   ✅   Backup of $FOLDER completed."
    done

    if [ "$DOCKER" == "yes" ]; then
        echo ""
        FOLDER_SIZE_H=$(du -hs /var/lib/docker $ARG_EXCLUDE_FOLDER $ARG_EXCLUDE_EXTENSIONS | awk '{print $1}')
        FOLDER_SIZE=$(du -s /var/lib/docker $ARG_EXCLUDE_FOLDER $ARG_EXCLUDE_EXTENSIONS | awk '{print $1}')
        FOLDER_TOTAL_SIZE=$(echo "$FOLDER_TOTAL_SIZE + $FOLDER_SIZE" | bc)
        echo "[$(date +%Y-%m-%d_%H:%M:%S)]   BackupScript   🌀   Backup of Docker folders ($FOLDER_SIZE_H) started."
        if [[ $DRY_RUN == "yes" ]]; then
                $DRY "Backup $FOLDER (with $ARG_EXCLUDE_FOLDER and $ARG_EXCLUDE_FOLDER) to $BACKUPFOLDER/docker-$DATE.tar.gz" $DRY2
            else
                /bin/tar -c $ARG_EXCLUDE_FOLDER $ARG_EXCLUDE_EXTENSIONS /var/lib/docker -P | pv -s $(du -sb /var/lib/docker | awk '{print $1}') | gzip > $BACKUPFOLDER/docker-$DATE.tar.gz
            fi
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

         if [[ DRY_RUN == "no" ]]; then
            DB_TOTAL_SIZE_H=$(du -hs $BACKUPFOLDER/databases/ | awk '{print $1}')
            DB_TOTAL_SIZE=$(du -s $BACKUPFOLDER/databases/ | awk '{print $1}')
        fi


    done
}

# Dry-run informations

function Dry-informations {
    printf '=%.0s' {1..100}
    echo $FOLDER_TOTAL_SIZE
    FOLDER_TOTAL_SIZE_H=$(echo $FOLDER_TOTAL_SIZE | awk '{$1=$1/(1024^2); print $1,"GB";}')
    echo ""
    echo "[$(date +%Y-%m-%d_%H:%M:%S)]   BackupScript   🔷   FREE SPACE : $FREE_SPACE_H"
    echo "[$(date +%Y-%m-%d_%H:%M:%S)]   BackupScript   🔷   BACKUP FOLDERS SIZE : ~ $FOLDER_TOTAL_SIZE_H"
    echo ""
    printf '=%.0s' {1..100}

}

function Run-informations {
    printf '=%.0s' {1..100}
    echo ""
    FOLDER_TOTAL_SIZE_H=$(echo $FOLDER_TOTAL_SIZE | awk '{$1=$1/(1024^2); print $1,"GB";}')
    FREE_SPACE_AFTER_H=$(echo "$FREE_SPACE - $FOLDER_TOTAL_SIZE - $DB_TOTAL_SIZE" | bc | awk '{$1=$1/(1024^2); print $1,"GB";}')

    echo "[$(date +%Y-%m-%d_%H:%M:%S)]   BackupScript   🔷   FREE SPACE BEFORE : $FREE_SPACE_H"
    echo "[$(date +%Y-%m-%d_%H:%M:%S)]   BackupScript   🔷   BACKUP FOLDERS SIZE : ~ $FOLDER_TOTAL_SIZE_H"
    echo "[$(date +%Y-%m-%d_%H:%M:%S)]   BackupScript   🔷   BACKUP DATABASE SIZE : ~ $DB_TOTAL_SIZE_H"
    echo "[$(date +%Y-%m-%d_%H:%M:%S)]   BackupScript   🔷   FREE SPACE AFTER : ~ $FREE_SPACE_AFTER_H"


    echo ""
    printf '=%.0s' {1..100}

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
if [[ $DRY_RUN == "yes" ]]; then
    Dry-informations
else
    Run-informations
fi
