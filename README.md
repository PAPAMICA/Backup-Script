
![Backup Script](https://send.papamica.fr/f.php?h=3Ms9ymej&p=1)

[![fr](https://img.shields.io/badge/lang-fr-blue.svg)](https://github.com/PAPAMICA/Backup-Script/blob/master/README_FR.md)

# Presentation
BackupScript is a bash script that allows you to backup a Linux server or machine directly in Infomaniak's kDrive and/or SwissBackup. It can also use other Rclone configurations for backup destinations.
It natively includes support for Zabbix and Grafana as well as Discord notifications.
![Dashboard Grafana](https://send.papamica.fr/f.php?h=0eBOcqx2&p=1)

# Prerequisites
Install the necessary packages with the following commands:
```sh
apt install -y mariadb-client pv curl zabbix-sender jq bc
curl https://rclone.org/install.sh | sudo bash
```
# Configuration
All the configuration parameters must be filled in the file `backup-script.conf` :

## General
| VARIABLE | DESCRIPTION |
|--|--|
| DATE | Configure the date format |
| HOUR | Configure the time format |
| WORKFOLDER | Configure the working directory (to be excluded from the backup) |
| SERVER_NAME | Configure the server name for the backup folder |
| BACKUPFOLDER | Configure the name of the folder containing the backup |
| KDRIVE | `yes/no` Enable the kDrive configuration |
| SWISS_BACKUP | `yes/no` Enable the configuration of Swiss Backup |
| ZABBIX | `yes/no` Enable monitoring with Zabbix |
| DISCORD |  `yes/no` Enable Discord notifications |
| DOCKER | `yes/no` Enables dump and backup of containerized databases |
| FOLDERS | Configure the list of folders to back up |
| EXCLUDE_FOLDERS | Configure the list of folders to exclude from backup |
| EXCLUDE_EXTENSIONS | Configure the list of extensions to exclude from the backup |
| RETENTION_DAYS | Number of days before objects are deleted from Swiss Backup |
| SEGMENT_SIZE | Block size for Swiss Backup |

## kDrive
| VARIABLE | DESCRIPTION |
|--|--|
| kd_user | Your Infomaniak ID |
| kd_pass | The application password created for the script |
| kd_folder | The path to your backup files in your kDrive |

**Liens utiles :**
kDrive : https://www.infomaniak.com/fr/kdrive
Application password : https://manager.infomaniak.com/v3/profile/application-password

## Swiss Backup
Il all you have to do is put the parameters that you retrieve in the Rclone file by email when creating the device in Swiss Backup.
| VARIABLE | DESCRIPTION |
|--|--|
| SB_QUOTA | Configure the maximum quota of your Swiss Backup (in go) |

**Liens utiles :**
Swiss Backup : https://www.infomaniak.com/en/swiss-backup

## Rclone
If you want to use the script with a destination other than kDrive or Swiss Backup, you can! You just have to create the configurations in Rclone and put their name in the following variable:
| VARIABLE | DESCRIPTION |
|--|--|
| RCLONE_CONFIGS | Rclone configurations to use (separated by spaces) |

**Liens utiles :**
Rclone : https://rclone.org

## Zabbix
| VARIABLE | DESCRIPTION |
|--|--|
| ZABBIX_SENDER | Link to zabbix_sender binary |
| ZABBIX_HOST | The name of your HOST in the Zabbix server |
| ZABBIX_SRV | The IP or DDNS of your Zabbix server |
| ZABBIX_DATA | Location of Zabbix temporary data file |

**Liens utiles :**
Zabbix : https://www.zabbix.com
Tutoriels : https://wiki-tech.io/fr/Supervision

## Discord
| VARIABLE | DESCRIPTION |
|--|--|
| DISCORD_WEBHOOK | The Webhook of your Discord bot |

**Liens utiles :**
Discord : https://discord.com
Configure Webhooks Discord : https://www.digitalocean.com/community/tutorials/how-to-use-discord-webhooks-to-get-notifications-for-your-website-status-on-ubuntu-18-04

# Utilisation
Clone the script on your machine: 
```sh
git clone https://github.com/PAPAMICA/Backup-Script
```
Go to the folder:
```sh
cd Backup-Script
```
Edit the file `backup-script.conf` with your settings :
```sh
nano backup-script.conf
```
Run the script :
```sh
./backup-script.sh
```

## Cronjog
Start backup every day at 02h
```sh
crontab -e
00 02 * * * /apps/Backup-Script/backup-script.sh >> /var/log/BackupScript.log
```

## The available settings
### Dry run
With  `--dry-run` you can preview what the script will do before you run it.
### List backup
With `--list-backup <CONFIG_RCLONE>` you can list the backups available in your outsourced storage.
### Zabbix send
With `--zabbix-send` you can force the sending of the latest data collected to Zabbix.

## Zabbix
To use backup monitoring with Zabbix, you must import and assign the template to your host `Template_Zabbix_App_BackupScript.xml`.
The first sending of data can be long or failed, do not hesitate to renew with :
```sh
./backup-script.sh --zabbix-send
```
## Grafana
You can import the template `Template_Grafana_BackupScript.json` directly in your Grafana instance.
You will need to modify the variable `$SERVER` in order to use the template correctly.


If my work has been useful to you, do not hesitate to offer me a strawberry milk 😃

[!["Buy Me A Coffee"](https://www.buymeacoffee.com/assets/img/custom_images/orange_img.png)](https://www.buymeacoffee.com/PAPAMICA)
