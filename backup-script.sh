#!/bin/bash

###############################################################################################
#####                                    BACKUP SCRIPT                                    #####
#####                             BY MICKAEL ASSELINE (PAPAMICA)                          #####
#####                                     WIKI-TECH.IO                                    #####
###############################################################################################

###############################################################################################
#####                                   GET CONFIG FILE                                   #####
###############################################################################################
FILE_CONF="/apps/Backup-Script/backup-script.conf" # Config file
if [[ -r $FILE_CONF ]]; then
    . $FILE_CONF
    echo "[$(date +%Y-%m-%d_%H:%M:%S)]   BackupScript   ✅   Config file charged !"
else
    echo "[$(date +%Y-%m-%d_%H:%M:%S)]   BackupScript   ❌   ERROR : Can't charge config file !"
    # Comment this line if you don't use Zabbix
    zabbix_sender -z "<ZABBIX_SERVER>" -s "<HOST_ZABBIX>" -k "backup.status" -o "1"
    
    exit
fi

###############################################################################################
#####                                  CHECK IF --dry-run                                 #####
###############################################################################################
if [[ $1 =~ "--dry-run" ]]; then
    DRY='echo ['$(date +%Y-%m-%d_%H:%M:%S)']---BackupScript---🚧---DRY RUN : [ '
    DRY2=' ]'
    DRY_RUN="yes"
else
    DRY=""
    DRY2=""
    DRY_RUN="no"
fi

###############################################################################################
#####                                CHECK IF --list-backup                               #####
###############################################################################################
if [[ $1 =~ "--list-backup" ]]; then
    OPTION_LIST_BACKUP=1
    LIST_BACKUP=$2
fi

###############################################################################################
#####                                CHECK IF --zabbix-send                               #####
###############################################################################################
if [[ $1 =~ "--zabbix-send" ]]; then
    ZABBIX_SEND="yes"
else
    if [[ -r $ZABBIX_DATA ]]; then
    rm $ZABBIX_DATA
    fi
fi


FOLDER_TOTAL_SIZE=0
FREE_SPACE_H=$(df -h $WORKFOLDER | awk 'FNR==2{print $4}')
FREE_SPACE=$(df $WORKFOLDER | awk 'FNR==2{print $4}')
DELETE_AFTER=$(( $RETENTION_DAYS * 24 * 60 * 60 ))
BACKUP_ERROS=0



###############################################################################################
#####                                 INSTALL REQUIREMENTS                                #####
###############################################################################################
function Install-Requirements {
    apt install -y mariadb-client pv curl zabbix-sender jq bc
    curl https://rclone.org/install.sh | sudo bash
    echo "[$(date +%Y-%m-%d_%H:%M:%S)]   BackupScript   ✅  All requirements is installed."
    echo ""
    printf '=%.0s' {1..100}
    echo ""
}



###############################################################################################
#####                           CREATE RCLONE CONFIG FOR KDRIVE                           #####
###############################################################################################
function Create-Rclone-Config-kDrive {
    RCLONE_CHECK_KDRIVE=$(rclone config show | grep kDrive)
    if [ -n "$RCLONE_CHECK_KDRIVE" ]; then
        echo "[$(date +%Y-%m-%d_%H:%M:%S)]   BackupScript   🌀   kDrive config already exist."
    else
        echo "[$(date +%Y-%m-%d_%H:%M:%S)]   BackupScript   🌀   Create kDrive config for rclone."
        $DRY rclone config create kDrive webdav url "https://connect.drive.infomaniak.com/$kd_folder" vendor other user "$kd_user" $DRY2    
        $DRY rclone config  password kDrive pass "$kd_pass" $DRY2
        if [[ $DRY_RUN == "yes" ]]; then
            $DRY Create Rclone config for kDrive $DRY2
        else
            RCLONE_CHECK_KDRIVE=$(rclone config show | grep kDrive)
            if [ -n "$RCLONE_CHECK_KDRIVE" ]; then
                echo "[$(date +%Y-%m-%d_%H:%M:%S)]   BackupScript   ✅   kDrive config created for rclone."
            else
                echo "[$(date +%Y-%m-%d_%H:%M:%S)]   BackupScript   ❌   ERROR : kDrive config didn't created, please check that !"
                
                if [[ $ZABBIX == "yes" ]]; then
                    Send-Zabbix-Data "backup.status" "1"
                fi
                exit
            fi
        fi
    fi
    echo ""
    printf '=%.0s' {1..100}
    echo ""
}

###############################################################################################
#####                         CREATE RCLONE CONFIG FOR SWISSBACKUP                        #####
###############################################################################################
function Create-Rclone-Config-SwissBackup {
    RCLONE_CHECK_SWISS_BACKUP=$(rclone config show | grep SwissBackup)
    if [ -n "$RCLONE_CHECK_SWISS_BACKUP" ]; then
        echo "[$(date +%Y-%m-%d_%H:%M:%S)]   BackupScript   🌀   SwissBackup config already exist."
    else
        echo "[$(date +%Y-%m-%d_%H:%M:%S)]   BackupScript   🌀   Create SwissBackup config for rclone."
        $DRY rclone config create SwissBackup swift user "$sb_user" key "$sb_key" auth "$sb_auth" domain "$sb_domain" tenant "$sb_tenant" tenant_domain "$sb_tenant_domain" region "$sb_region" $DRY2
        if [[ $DRY_RUN == "yes" ]]; then
            $DRY Create Rclone config for SwissBackup $DRY2
        else
            RCLONE_CHECK_SWISS_BACKUP=$(rclone config show | grep SwissBackup)
            if [ -n "$RCLONE_CHECK_SWISS_BACKUP" ]; then
                echo "[$(date +%Y-%m-%d_%H:%M:%S)]   BackupScript   ✅   SwissBackup config created for rclone."
            else
                echo "[$(date +%Y-%m-%d_%H:%M:%S)]   BackupScript   ❌   ERROR : SwissBackup config didn't created, please check that !"
                if [[ $ZABBIX == "yes" ]]; then
                    Send-Zabbix-Data "backup.status" "1"
                fi
                exit
            fi
        fi
    fi
    echo ""
    printf '=%.0s' {1..100}
    echo ""
}



###############################################################################################
#####                              BACKUP FOLDERS TO ARCHIVES                             #####
###############################################################################################
function Backup-Folders {
    FOLDERS_BACKUP_ERRORS=0
    FOLDERS_COUNT=0
    FOLDER_COUNT_VAR=$(echo $FOLDERS | wc -w)
    echo ""
    cd $WORKFOLDER
    $DRY /bin/mkdir -p $SERVER_NAME/$BACKUPFOLDER $DRY2
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

        echo "[$(date +%Y-%m-%d_%H:%M:%S)]   BackupScript   🌀   Calculate the size of folder $FOLDER, please wait ..."
        FOLDER_SIZE_H=$(du -bhs $FOLDER $ARG_EXCLUDE_FOLDER $ARG_EXCLUDE_EXTENSIONS | awk '{print $1}')
        FOLDER_SIZE=$(du -bs $FOLDER $ARG_EXCLUDE_FOLDER $ARG_EXCLUDE_EXTENSIONS | awk '{print $1}')
        FOLDER_TOTAL_SIZE=$(echo "$FOLDER_TOTAL_SIZE + $FOLDER_SIZE" | bc)
        FOLDER_NAME=$(basename $FOLDER)
        echo "[$(date +%Y-%m-%d_%H:%M:%S)]   BackupScript   🌀   Backup of $FOLDER ($FOLDER_SIZE_H) started."
        if [[ $DRY_RUN == "yes" ]]; then
                $DRY "Backup $FOLDER (with $ARG_EXCLUDE_FOLDER and $ARG_EXCLUDE_FOLDER) to $SERVER_NAME/$BACKUPFOLDER/$FOLDER_NAME-$DATE.tar.gz" $DRY2
            else
                /bin/tar -c $ARG_EXCLUDE_FOLDER $ARG_EXCLUDE_EXTENSIONS ${FOLDER} -P | pv -s $FOLDER_SIZE | gzip > $SERVER_NAME/$BACKUPFOLDER/$FOLDER_NAME-$DATE.tar.gz
                status=$?
                if test $status -eq 0; then
                    echo "[$(date +%Y-%m-%d_%H:%M:%S)]   BackupScript   ✅   Backup of $FOLDER completed."
                    ((FOLDERS_COUNT++))
                    if [[ $ZABBIX == "yes" ]]; then
                        if test $FOLDERS_COUNT -eq 1; then
                            ZABBIX_FOLDER_INV=$(echo "{ \"data\": [")
                        fi
                        ZABBIX_FOLDER_INV=$(echo "$ZABBIX_FOLDER_INV{ \"{#FOLDER}\":\"$FOLDER_NAME\" }")
                        if test $FOLDERS_COUNT -ne $FOLDER_COUNT_VAR; then
                            ZABBIX_FOLDER_INV=$(echo "$ZABBIX_FOLDER_INV,")
                        fi
                        if test $FOLDERS_COUNT -eq $FOLDER_COUNT_VAR; then
                            ZABBIX_FOLDER_INV=$(echo "$ZABBIX_FOLDER_INV]}")
                        fi
                    fi
                else
                    echo "[$(date +%Y-%m-%d_%H:%M:%S)]   BackupScript   ❌   ERROR : A problem was encountered during the backup of $FOLDER."
                    ((FOLDERS_BACKUP_ERRORS++))
                    ((BACKUP_ERROS++))
                fi
                FOLDER_SIZE_AFTER_H=$(du -bhs $SERVER_NAME/$BACKUPFOLDER/$FOLDER_NAME-$DATE.tar.gz | awk '{print $1}')
                FOLDER_SIZE_AFTER=$(du -bs $SERVER_NAME/$BACKUPFOLDER/$FOLDER_NAME-$DATE.tar.gz | awk '{print $1}')
                echo "                                            🔹 [ $FOLDER_NAME ] - $FOLDER : $FOLDER_SIZE_H ($FOLDER_SIZE_AFTER_H)" >> folders.txt
                if [[ $ZABBIX == "yes" ]]; then
                    echo "\"$ZABBIX_HOST"\" backup.folder.size[$FOLDER_NAME] $FOLDER_SIZE_AFTER >> $ZABBIX_DATA    
                fi
                
            fi
        
        FOLDER_LIST=$(echo "$FOLDER_LIST $FOLDER")
    done
    echo ""
    printf '=%.0s' {1..100}
    echo ""
}



###############################################################################################
#####                             DUMP ALL CONTAINERS DATABASES                           #####
###############################################################################################
function Backup-Database {
    DB_BACKUP_ERRORS=0
    DB_COUNT=0
    echo ""
    cd $WORKFOLDER
    $DRY /bin/mkdir -p $SERVER_NAME/$BACKUPFOLDER/databases $DRY2
    CONTAINER_DB=$(docker ps | grep -E 'mariadb|mysql|postgres|-db' | awk '{print $NF}')
    DB_COUNT_VAR=$(echo $CONTAINER_DB | wc -w)
    for CONTAINER_NAME in $CONTAINER_DB; do
        echo ""
        echo "[$(date +%Y-%m-%d_%H:%M:%S)]   BackupScript   🌀   Backup database of $CONTAINER_NAME started."
        DB_VERSION=$(docker ps | grep -w $CONTAINER_NAME | awk '{print $2}')

        if [[ $DB_VERSION == *"mariadb"* ]] || [[ $DB_VERSION == *"mysql"* ]]; then
            DB_USER=$(docker exec $CONTAINER_NAME bash -c 'echo "$MYSQL_USER"')
            DB_PASSWORD=$(docker exec $CONTAINER_NAME bash -c 'echo "$MYSQL_PASSWORD"')
            DB_DATABASE=$(docker exec $CONTAINER_NAME bash -c 'echo "$MYSQL_DATABASE"')
            SQLFILE="$SERVER_NAME/$BACKUPFOLDER/databases/$CONTAINER_NAME-mysql-$DATE.sql"
            if [[ $DRY_RUN == "yes" ]]; then
                $DRY Execute dump of database in $CONTAINER_NAME $DRY2
            else
                docker exec -e MYSQL_PWD=$DB_PASSWORD $CONTAINER_NAME /usr/bin/mysqldump -u $DB_USER --no-tablespaces $DB_DATABASE > $SQLFILE
                status=$?
                if test $status -eq 0; then
                    echo "[$(date +%Y-%m-%d_%H:%M:%S)]   BackupScript   ✅   Backup database of $CONTAINER_NAME completed."
                    ((DB_COUNT++))
                    if [[ $ZABBIX == "yes" ]]; then
                        if test $DB_COUNT -eq 1; then
                            ZABBIX_DB_INV=$(echo "{ \"data\": [")
                        fi
                        ZABBIX_DB_INV=$(echo "$ZABBIX_DB_INV{ \"{#DB}\":\"$CONTAINER_NAME\" }")
                        if test $DB_COUNT -ne $DB_COUNT_VAR; then
                            ZABBIX_DB_INV=$(echo "$ZABBIX_DB_INV,")
                        fi
                        if test $DB_COUNT -eq $DB_COUNT_VAR; then
                            ZABBIX_DB_INV=$(echo "$ZABBIX_DB_INV]}")
                        fi
                    fi
                else
                    echo "[$(date +%Y-%m-%d_%H:%M:%S)]   BackupScript   ❌   ERROR : A problem was encountered during the backup database of $CONTAINER_NAME."
                    ((DB_BACKUP_ERRORS++))
                    ((BACKUP_ERROS++))
                fi
                DB_SIZE_AFTER_H=$(du -bhs $SQLFILE | awk '{print $1}')
                DB_SIZE_AFTER=$(du -bs $SQLFILE | awk '{print $1}')
                echo "                                            🔹 [ $CONTAINER_NAME ] - $CONTAINER_NAME-mysql-$DATE.sql : $DB_SIZE_AFTER_H" >> databases.txt
                if [[ $ZABBIX == "yes" ]]; then
                    echo "\"$ZABBIX_HOST"\" backup.db.size[$CONTAINER_NAME] $DB_SIZE_AFTER >> $ZABBIX_DATA    
                fi
            fi
            
        elif [[ $DB_VERSION == *"postgres"* ]]; then
            DB_USER=$(docker exec $CONTAINER_NAME bash -c 'echo "$POSTGRES_USER"')
            DB_PASSWORD=$(docker exec $CONTAINER_NAME bash -c 'echo "$POSTGRES_PASSWORD"')
            SQLFILE="$SERVER_NAME/$BACKUPFOLDER/databases/$CONTAINER_NAME-postgres-$DATE.sql"
            if [[ $DRY_RUN == "yes" ]]; then
                $DRY Execute dump of database in $CONTAINER_NAME $DRY2
            else
                docker exec -t $CONTAINER_NAME pg_dumpall -c -U $DB_USER > $SQLFILE
                status=$?
                if test $status -eq 0; then
                    echo "[$(date +%Y-%m-%d_%H:%M:%S)]   BackupScript   ✅   Backup database of $CONTAINER_NAME completed."
                    ((DB_COUNT++))
                    if [[ $ZABBIX == "yes" ]]; then
                        if test $DB_COUNT -eq 1; then
                            ZABBIX_DB_INV=$(echo "{ \"data\": [")
                        fi
                        ZABBIX_DB_INV=$(echo "$ZABBIX_DB_INV{ \"{#DB}\":\"$CONTAINER_NAME\" }")
                        if test $DB_COUNT -ne $DB_COUNT_VAR; then
                            ZABBIX_DB_INV=$(echo "$ZABBIX_DB_INV,")
                        fi
                        if test $DB_COUNT -eq $DB_COUNT_VAR; then
                            ZABBIX_DB_INV=$(echo "$ZABBIX_DB_INV]}")
                        fi
                    fi
                else
                    echo "[$(date +%Y-%m-%d_%H:%M:%S)]   BackupScript   ❌   ERROR : A problem was encountered during the backup database of $CONTAINER_NAME."
                    ((DB_BACKUP_ERRORS++))
                    if [[ $ZABBIX == "yes" ]]; then
                        Send-Zabbix-Data "backup.status" "1"
                    fi
                fi
                DB_SIZE_AFTER_H=$(du -bhs $SQLFILE | awk '{print $1}')
                DB_SIZE_AFTER=$(du -bs $SQLFILE | awk '{print $1}')
                echo "                                            🔹 [ $CONTAINER_NAME ] - $CONTAINER_NAME-postgres-$DATE.sql : $DB_SIZE_AFTER_H" >> databases.txt
                if [[ $ZABBIX == "yes" ]]; then
                    echo "\"$ZABBIX_HOST"\" backup.db.size[$CONTAINER_NAME] $DB_SIZE_AFTER >> $ZABBIX_DATA    
                fi
            fi
        else
            echo "[$(date +%Y-%m-%d_%H:%M:%S)]   BackupScript   ❌   ERROR : Can't get credentials of $CONTAINER_NAME."
            ((DB_BACKUP_ERRORS++))
            ((BACKUP_ERROS++))
        fi

        SIZE=5000
        if [[ DRY_RUN == "no" ]] && [ "$(du -bsb $SQLFILE | awk '{ print $1 }')" -le $SIZE ]; then
            echo "[$(date +%Y-%m-%d_%H:%M:%S)]   BackupScript   ⚠️   WARNING : Backup file of $CONTAINER_NAME is smaller than 1Mo."
            ((DB_BACKUP_ERRORS++))
            ((BACKUP_ERROS++))
        fi
            
        DB_LIST=$(echo "$DB_LIST $CONTAINER_NAME")


    done
    echo ""
    printf '=%.0s' {1..100}
    echo ""
}

###############################################################################################
#####                                  SHOW INFORMATIONS                                  #####
###############################################################################################
function Dry-informations {
    FOLDER_TOTAL_SIZE_H=$(echo $FOLDER_TOTAL_SIZE | awk '{$1=$1/(1024^3); print $1,"G";}')
    echo "[$(date +%Y-%m-%d_%H:%M:%S)]   BackupScript   🔷   FREE SPACE : $FREE_SPACE_H"
    echo "[$(date +%Y-%m-%d_%H:%M:%S)]   BackupScript   🔷   BACKUP FOLDERS SIZE : ~ $FOLDER_TOTAL_SIZE_H"
    echo ""
    printf '=%.0s' {1..100}
    echo ""
}

function Run-informations {
    DB_TOTAL_SIZE_H=$(du -bhs $SERVER_NAME/$BACKUPFOLDER/databases/ | awk '{print $1}')
    DB_TOTAL_SIZE=$(du -bs $SERVER_NAME/$BACKUPFOLDER/databases/ | awk '{print $1}')
    FOLDER_TOTAL_SIZE_H=$(echo $FOLDER_TOTAL_SIZE | awk '{$1=$1/(1024^3); print $1,"G";}')
    FOLDER_TOTAL_SIZE_COMPRESSED=$(du -bs $SERVER_NAME/$BACKUPFOLDER | awk '{print $1}')
    FOLDER_TOTAL_SIZE_COMPRESSED_H=$(du -bhs $SERVER_NAME/$BACKUPFOLDER | awk '{print $1}')
    FREE_SPACE_AFTER_H=$(df -h $WORKFOLDER | awk 'FNR==2{print $4}')
    echo "[$(date +%Y-%m-%d_%H:%M:%S)]   BackupScript   🔷   FREE SPACE BEFORE : $FREE_SPACE_H"
    echo "[$(date +%Y-%m-%d_%H:%M:%S)]   BackupScript   🔷   BACKUP FOLDERS SIZE : ~ $FOLDER_TOTAL_SIZE_H"
    echo "$(<folders.txt)" 
    echo "[$(date +%Y-%m-%d_%H:%M:%S)]   BackupScript   🔷   BACKUP DATABASE SIZE : ~ $DB_TOTAL_SIZE_H"
    echo "$(<databases.txt)" 
    echo "[$(date +%Y-%m-%d_%H:%M:%S)]   BackupScript   🔷   BACKUP TOTAL SIZE COMPRESSED : ~ $FOLDER_TOTAL_SIZE_COMPRESSED_H"
    rm folders.txt databases.txt
    echo ""
    printf '=%.0s' {1..100}
    echo ""
}

###############################################################################################
#####                                 SEND TO SWISSBACKUP                                 #####
###############################################################################################
function Send-to-SwissBackup {
    echo "[$(date +%Y-%m-%d_%H:%M:%S)]   BackupScript   🌀   Send to SwissBackup started."
    rclone mkdir SwissBackup:$SERVER_NAME/$BACKUPFOLDER
    rclone -P copy --header-upload "X-Delete-After: $DELETE_AFTER" $WORKFOLDER/$SERVER_NAME/$BACKUPFOLDER SwissBackup:$SERVER_NAME/$BACKUPFOLDER
    status=$?
    if test $status -eq 0; then
        BACKUP_STATUS=$(echo "$BACKUP_STATUS 🟢 SwissBackup")
        ZB_BACKUP_STATUS=$(echo "$ZB_BACKUP_STATUS SwissBackup")
        echo "[$(date +%Y-%m-%d_%H:%M:%S)]   BackupScript   ✅   Backup are uploaded to SwissBackup."
    else
        BACKUP_STATUS=$(echo "$BACKUP_STATUS 🔴 SwissBackup")
        echo "[$(date +%Y-%m-%d_%H:%M:%S)]   BackupScript   ❌   ERROR : A problem was encountered during the upload to SwissBackup."
        ((BACKUP_ERROS++))
    fi

    echo ""
    printf '=%.0s' {1..100}
    echo ""
}

###############################################################################################
#####                                    SEND TO KDRIVE                                   #####
###############################################################################################
function Send-to-kDrive {
    echo "[$(date +%Y-%m-%d_%H:%M:%S)]   BackupScript   🌀   Send to kDrive started."
    rclone -P copy $WORKFOLDER/$SERVER_NAME/$BACKUPFOLDER kDrive:$SERVER_NAME/$BACKUPFOLDER
    status=$?
    if test $status -eq 0; then
        BACKUP_STATUS=$(echo "$BACKUP_STATUS 🟢 kDrive")
        ZB_BACKUP_STATUS=$(echo "$ZB_BACKUP_STATUS kDrive")
        echo "[$(date +%Y-%m-%d_%H:%M:%S)]   BackupScript   ✅   Backup are uploaded to kDrive."
    else
        BACKUP_STATUS=$(echo "$BACKUP_STATUS 🔴 kDrive")
        echo "[$(date +%Y-%m-%d_%H:%M:%S)]   BackupScript   ❌   ERROR : A problem was encountered during the upload to kDrive."
        ((BACKUP_ERROS++))
    fi
    echo ""
    printf '=%.0s' {1..100}
    echo ""
}

###############################################################################################
#####                             SEND TO OTHER CONFIG RCLONE                             #####
###############################################################################################
function Send-to-config-rclone {
    for CONFIG in $RCLONE_CONFIGS; do
        echo "[$(date +%Y-%m-%d_%H:%M:%S)]   BackupScript   🌀   Send to $CONFIG started."
        ZABBIX_DESTINATIONS=$(echo "$ZABBIX_DESTINATIONS $CONFIG")
        rclone -P copy $WORKFOLDER/$SERVER_NAME/$BACKUPFOLDER $CONFIG:$SERVER_NAME/$BACKUPFOLDER
        status=$?
        if test $status -eq 0; then
            BACKUP_STATUS=$(echo "$BACKUP_STATUS 🟢 $CONFIG")
            ZB_BACKUP_STATUS=$(echo "$ZB_BACKUP_STATUS $CONFIG")
            echo "[$(date +%Y-%m-%d_%H:%M:%S)]   BackupScript   ✅   Backup are uploaded to $CONFIG."
        else
            BACKUP_STATUS=$(echo "$BACKUP_STATUS 🔴 $CONFIG")
            echo "[$(date +%Y-%m-%d_%H:%M:%S)]   BackupScript   ❌   ERROR : A problem was encountered during the upload to $CONFIG."
            ((BACKUP_ERROS++))
        fi
        echo ""
        printf '=%.0s' {1..100}
        echo ""
    done
}

###############################################################################################
#####                                     LIST BACKUP                                     #####
###############################################################################################
function List-Backup {
    if [ -n "$LIST_BACKUP" ]; then
        echo ""
        echo "Backups availables on $LIST_BACKUP :"
        rclone lsf $LIST_BACKUP:$SERVER_NAME
    else
        if [[ $KDRIVE == "yes" ]]; then
            LIST_BACKUP=$(echo "$LIST_BACKUP kDrive")
        fi
        if [[ $SWISS_BACKUP == "yes" ]]; then
            LIST_BACKUP=$(echo "$LIST_BACKUP SwissBackup")
        fi

        if [ -n "$RCLONE_CONFIGS" ]; then
            LIST_BACKUP=$(echo "$LIST_BACKUP $RCLONE_CONFIGS")
        fi
        for CONFIG in $LIST_BACKUP; do
            echo ""
            echo "Backups availables on $CONFIG :"
            rclone lsf $CONFIG:$SERVER_NAME
        done
    fi

    
}

###############################################################################################
#####                             SEND INFORMATIONS TO ZABBIX                             #####
###############################################################################################
function Send-To-Zabbix {

    if [[ $DRY_RUN == "yes" ]]; then
        $DRY "Send data to Zabbix server (Host : "$ZABBIX_HOST" / Server : "$ZABBIX_SRV")" $DRY2
    else
        if [[ $KDRIVE == "yes" ]]; then
            ZABBIX_DESTINATIONS=$(echo "$ZABBIX_DESTINATIONS kDrive")
        fi
        if [[ $SWISS_BACKUP == "yes" ]]; then
            ZABBIX_DESTINATIONS=$(echo "$ZABBIX_DESTINATIONS SwissBackup")
        fi
        DESTINATIONS_COUNT=0
        DESTINATIONS_COUNT_VAR=$(echo $ZABBIX_DESTINATIONS | wc -w)
        for DESTINATION in $ZABBIX_DESTINATIONS; do
            ((DESTINATIONS_COUNT++))
            if test $DESTINATIONS_COUNT -eq 1; then
                ZABBIX_DESTINATIONS=$(echo "{ \"data\": [")
            fi
            ZABBIX_DESTINATIONS=$(echo "$ZABBIX_DESTINATIONS{ \"{#DESTINATION}\":\"$DESTINATION\" }")
            if test $DESTINATIONS_COUNT -ne $DESTINATIONS_COUNT_VAR; then
                ZABBIX_DESTINATIONS=$(echo "$ZABBIX_DESTINATIONS,")
            fi
            if test $DESTINATIONS_COUNT -eq $DESTINATIONS_COUNT_VAR; then
                ZABBIX_DESTINATIONS=$(echo "$ZABBIX_DESTINATIONS]}")
            fi
            
            if [[ $DESTINATION == "SwissBackup" ]]; then
                ZB_TOTAL=$(echo "$SB_QUOTA * 1000000000" | bc)
            else
                ZB_TOTAL_TEMP=$(rclone about $DESTINATION: | grep Total | awk '{print $2}')
                if [[ ${ZB_TOTAL_TEMP: -1} == "T" ]]; then
                    ZB_TOTAL=$(echo "${ZB_TOTAL_TEMP::-1} * 1000000000000" | bc)
                    elif [[ ${ZB_TOTAL_TEMP: -1} == "G" ]]; then
                        ZB_TOTAL=$(echo "${ZB_TOTAL_TEMP::-1} * 1000000000" | bc)
                    elif [[ ${ZB_TOTAL_TEMP: -1} == "M" ]]; then
                        ZB_TOTAL=$(echo "${ZB_TOTAL_TEMP::-1} * 1000000" | bc)
                    elif [[ ${ZB_TOTAL_TEMP: -1} == "K" ]]; then
                        ZB_TOTAL=$(echo "${ZB_TOTAL_TEMP::-1} * 1000" | bc)
                    else
                        ZB_TOTAL=$ZB_TOTAL_TEMP
                fi
            fi
            ZB_USED_TEMP=$(rclone about $DESTINATION: | grep Used | awk '{print $2}')
            if [[ ${ZB_USED_TEMP: -1} == "T" ]]; then
                ZB_USED=$(echo "${ZB_USED_TEMP::-1} * 1000000000000" | bc)
                elif [[ ${ZB_USED_TEMP: -1} == "G" ]]; then
                    ZB_USED=$(echo "${ZB_USED_TEMP::-1} * 1000000000" | bc)
                elif [[ ${ZB_USED_TEMP: -1} == "M" ]]; then
                    ZB_USED=$(echo "${ZB_USED_TEMP::-1} * 1000000" | bc)
                elif [[ ${ZB_USED_TEMP: -1} == "K" ]]; then
                    ZB_USED=$(echo "${ZB_USED_TEMP::-1} * 1000" | bc)
                else
                    ZB_USED=$ZB_USED_TEMP
            fi
            ZB_POURCENT_USED=$(echo "$ZB_USED * 100 / $ZB_TOTAL" | bc)
            ZB_FREE=$(echo "$ZB_TOTAL - $ZB_USED" | bc)

            if [[ $ZB_BACKUP_STATUS == *"$DESTINATION"* ]]; then
                echo "\"$ZABBIX_HOST"\" backup.status[$DESTINATION] 0 >> $ZABBIX_DATA
            else
                echo "\"$ZABBIX_HOST"\" backup.status[$DESTINATION] 1 >> $ZABBIX_DATA
            fi
            if [ -n "$ZB_TOTAL" ]; then
                echo "\"$ZABBIX_HOST"\" backup.total[$DESTINATION] $ZB_TOTAL >> $ZABBIX_DATA
                echo "\"$ZABBIX_HOST"\" backup.free[$DESTINATION] $ZB_FREE >> $ZABBIX_DATA
                echo "\"$ZABBIX_HOST"\" backup.used[$DESTINATION] $ZB_USED >> $ZABBIX_DATA
                echo "\"$ZABBIX_HOST"\" backup.used.pourcent[$DESTINATION] $ZB_POURCENT_USED >> $ZABBIX_DATA
            fi
        done
        echo "\"$ZABBIX_HOST"\" backup.errors $BACKUP_ERROS >> $ZABBIX_DATA
        echo "\"$ZABBIX_HOST"\" backup.status 0 >> $ZABBIX_DATA
        echo "\"$ZABBIX_HOST"\" backup.date.last $DATE >> $ZABBIX_DATA
        echo "\"$ZABBIX_HOST"\" backup.hour.last $HOUR >> $ZABBIX_DATA
        echo "\"$ZABBIX_HOST"\" backup.size $FOLDER_TOTAL_SIZE >> $ZABBIX_DATA
        echo "\"$ZABBIX_HOST"\" backup.size.compressed $FOLDER_TOTAL_SIZE_COMPRESSED >> $ZABBIX_DATA
        echo "\"$ZABBIX_HOST"\" backup.time $RUN_TIME >> $ZABBIX_DATA
        echo "\"$ZABBIX_HOST"\" backup.folder.errors $FOLDERS_BACKUP_ERRORS >> $ZABBIX_DATA
        echo "\"$ZABBIX_HOST"\" backup.folder.count $FOLDERS_COUNT >> $ZABBIX_DATA
        echo "\"$ZABBIX_HOST"\" backup.folder.list $FOLDER_LIST >> $ZABBIX_DATA
        if [[ $DOCKER == "yes" ]]; then
            echo "\"$ZABBIX_HOST"\" backup.db.errors $DB_BACKUP_ERRORS >> $ZABBIX_DATA
            echo "\"$ZABBIX_HOST"\" backup.db.count $DB_COUNT >> $ZABBIX_DATA
            if test $DB_COUNT -gt 0; then
                echo "\"$ZABBIX_HOST"\" backup.db.list $DB_LIST >> $ZABBIX_DATA
            fi
        fi

        zabbix_sender -z "$ZABBIX_SRV" -s "$ZABBIX_HOST" -k "backup.folder.size.discovery" -o "$ZABBIX_FOLDER_INV"
        if [[ $DOCKER == "yes" ]]; then
            zabbix_sender -z "$ZABBIX_SRV" -s "$ZABBIX_HOST" -k "backup.db.size.discovery" -o "$ZABBIX_DB_INV"
        fi
        zabbix_sender -z "$ZABBIX_SRV" -s "$ZABBIX_HOST" -k "backup.destinations.discovery" -o "$ZABBIX_DESTINATIONS"
        zabbix_sender -z "$ZABBIX_SRV" -i $ZABBIX_DATA
        status=$?
        if test $status -eq 0; then
            echo "[$(date +%Y-%m-%d_%H:%M:%S)]   BackupScript   ✅   Data sended to Zabbix."
        else
            sleep 120
            zabbix_sender -vv -z $ZABBIX_SRV -i $ZABBIX_DATA
            status=$?
            if test $status -eq 0; then
                echo "[$(date +%Y-%m-%d_%H:%M:%S)]   BackupScript   ✅   Data sended to Zabbix."
            else
                echo "[$(date +%Y-%m-%d_%H:%M:%S)]   BackupScript   ❌   ERROR : A problem was encountered during the send data to Zabbix."
            fi
        fi
    fi
    echo ""
    printf '=%.0s' {1..100}
    echo ""
}

function Send-Zabbix-Force {
    zabbix_sender -z $ZABBIX_SRV -i $ZABBIX_DATA
    status=$?
    if test $status -eq 0; then
        echo "[$(date +%Y-%m-%d_%H:%M:%S)]   BackupScript   ✅   Data sended to Zabbix."
    else
        sleep 120
        zabbix_sender -vv -z $ZABBIX_SRV -i $ZABBIX_DATA
        status=$?
        if test $status -eq 0; then
            echo "[$(date +%Y-%m-%d_%H:%M:%S)]   BackupScript   ✅   Data sended to Zabbix."
        else
            echo "[$(date +%Y-%m-%d_%H:%M:%S)]   BackupScript   ❌   ERROR : A problem was encountered during the send data to Zabbix."
        fi
    fi
}

function Send-Zabbix-Data {
    zabbix_sender -z "$ZABBIX_SRV" -s "$ZABBIX_HOST" -k "$1" -o "$2"
    status=$?
    if test $status -eq 0; then
        echo "[$(date +%Y-%m-%d_%H:%M:%S)]   BackupScript   ✅   Data sended to Zabbix."
    else
        echo "[$(date +%Y-%m-%d_%H:%M:%S)]   BackupScript   ❌   ERROR : A problem was encountered during the send data to Zabbix."
    fi
}
###############################################################################################
#####                              SEND DISCORD NOTIFICATION                              #####
###############################################################################################
function Send-Discord-Notifications {
    ./discord.sh --webhook-url=$DISCORD_WEBHOOK --username "[$SERVER_NAME]" --text "Backup of $DATE" --title "Folders and databases have been successfully backed up !" --description "**Folders ($FOLDER_TOTAL_SIZE_H) :\n** $FOLDER_LIST\n\n**Databases ($DB_TOTAL_SIZE_H) :\n** $DB_LIST\n\n**Time :**\n $RUN_TIME_H" --color 0x4BF646 --footer "$BACKUP_STATUS" --footer-icon "https://send.papamica.fr/f.php?h=0QpaiREO&p=1"
    echo "[$(date +%Y-%m-%d_%H:%M:%S)]   BackupScript   ✅   Notification are sended to Discord"
    echo ""
    printf '=%.0s' {1..100}
    echo ""
}



###############################################################################################
#####                                      EXECUTION                                      #####
###############################################################################################
if [ -n "$OPTION_LIST_BACKUP" ]; then
    List-Backup
    exit
fi

if [[ $ZABBIX_SEND == "yes" ]]; then
    Send-Zabbix-Force
    exit
fi

START_TIME=$(date +%s)
if [[ $KDRIVE == "yes" ]]; then
    Create-Rclone-Config-kDrive
fi
if [[ $SWISS_BACKUP == "yes" ]]; then
    Create-Rclone-Config-SwissBackup
fi

Backup-Folders

if [[ $DOCKER == "yes" ]]; then
    Backup-Database
fi

if [[ $DRY_RUN == "yes" ]]; then
    Dry-informations
else
    Run-informations
    if [[ $KDRIVE == "yes" ]]; then
        Send-to-kDrive
    fi
    if [[ $SWISS_BACKUP == "yes" ]]; then
        Send-to-SwissBackup
    fi
    if [ -n "$RCLONE_CONFIGS" ]; then
        Send-to-config-rclone
    fi
fi
END_TIME=$(date +%s)
RUN_TIME=$((END_TIME-START_TIME))
RUN_TIME_H=$(eval "echo $(date -ud "@$RUN_TIME" +'$((%s/3600/24)) days %H hours %M minutes %S seconds')")
if [[ $DISCORD == "yes" ]]; then
    Send-Discord-Notifications
fi
if [[ $ZABBIX == "yes" ]]; then
    Send-To-Zabbix
fi

rm -rf $WORKFOLDER/$SERVER_NAME