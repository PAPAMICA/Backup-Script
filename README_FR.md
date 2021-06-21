
![Backup Script](https://send.papamica.fr/f.php?h=3Ms9ymej&p=1)

[![en](https://img.shields.io/badge/lang-en-red.svg)](https://github.com/PAPAMICA/Backup-Script/blob/master/README.md)

# Présentation
BackupScript est un script bash qui permet de sauvegarder un serveur ou une machine Linux directement dans kDrive et/ou SwissBackup d'Infomaniak. Il peux aussi utiliser d'autres configurations rClone pour les destinations de sauvegarde.
Il inclut nativement un support de  Zabbix et Grafana ainsi que les notifications Discord.
![Dashboard Grafana](https://send.papamica.fr/f.php?h=0eBOcqx2&p=1)

# Prérequis
Installez les paquets nécessaires avec les commandes suivantes : 
```sh
apt install -y mariadb-client pv curl zabbix-sender jq bc
curl https://rclone.org/install.sh | sudo bash
```
# Configuration
Tous les paramètres de configuration sont à remplir dans le fichier `backup-script.conf` :

## Général
| VARIABLE | DESCRIPTION |
|--|--|
| DATE | Configure le format de la date |
| HOUR | Configure le format de l'heure |
| WORKFOLDER | Configure le répertoire de travail (à exclure de la sauvegarde) |
| SERVER_NAME | Configure le nom du serveur pour le dossier de sauvegarde |
| BACKUPFOLDER | Configure le nom du dossier contenant la sauvegarde |
| KDRIVE | `yes/no` Active la configuration de kDrive |
| SWISS_BACKUP | `yes/no` Active la configuration de Swiss Backup |
| ZABBIX | `yes/no` Active la supervision avec Zabbix |
| DISCORD |  `yes/no` Active les notifications Discord |
| DOCKER | `yes/no` Active le dump et la sauvegarde des bases de données conteneurisées |
| FOLDERS | Configure la liste des dossiers à sauvegarder |
| EXCLUDE_FOLDERS | Configure la liste des dossiers à exclure de la sauvegarde |
| EXCLUDE_EXTENSIONS | Configure la liste des extensions à exclure de la sauvegarde |
| RETENTION_DAYS | Nombre de jours avant que les objets soit supprimés de Swiss Backup |
| SEGMENT_SIZE | Taille de block pour Swiss Backup |

## kDrive
| VARIABLE | DESCRIPTION |
|--|--|
| kd_user | Votre identifiant Infomaniak |
| kd_pass | Le mot de passe application créé pour le script |
| kd_folder | Le chemin vers votre dossiers de sauvegardes dans votre kDrive |

**Liens utiles :**
kDrive : https://www.infomaniak.com/fr/kdrive
Mot de passe application : https://manager.infomaniak.com/v3/profile/application-password

## Swiss Backup
Il vous suffit de mettre les paramètres que vous récupérez dans le fichier rClone par mail lors de la création de l'appareil dans Swiss Backup.
| VARIABLE | DESCRIPTION |
|--|--|
| SB_QUOTA | Configure le quota maximum de votre Swiss Backup (en go) |

**Liens utiles :**
Swiss Backup : https://www.infomaniak.com/fr/swiss-backup

## Rclone
Si vous souhaitez utiliser le script avec une autre destination que kDrive ou Swiss Backup, vous le pouvez ! Il vous suffit de créer les configurations dans Rclone et de mettre leur nom dans la variable suivante :
| VARIABLE | DESCRIPTION |
|--|--|
| RCLONE_CONFIGS | Configurations Rclone à utiliser (séparés par des espaces) |

**Liens utiles :**
Rclone : https://rclone.org

## Zabbix
| VARIABLE | DESCRIPTION |
|--|--|
| ZABBIX_SENDER | Lien vers le binaire de zabbix_sender |
| ZABBIX_HOST | Le nom de votre HOST dans le serveur Zabbix |
| ZABBIX_SRV | L'IP ou le DDNS de votre serveur Zabbix |
| ZABBIX_DATA | Localisation du fichier de données temporaires de Zabbix |

**Liens utiles :**
Zabbix : https://www.zabbix.com
Tutoriels : https://wiki-tech.io/fr/Supervision

## Discord
| VARIABLE | DESCRIPTION |
|--|--|
| DISCORD_WEBHOOK | Le Webhook de votre bot Discord |

**Liens utiles :**
Discord : https://discord.com
Configurer les Webhooks Discord : https://www.digitalocean.com/community/tutorials/how-to-use-discord-webhooks-to-get-notifications-for-your-website-status-on-ubuntu-18-04

# Utilisation
Clonez le script sur votre machine : 
```sh
git clone https://github.com/PAPAMICA/Backup-Script
```
Rendez vous dans le dossier :
```sh
cd Backup-Script
```
Modifiez le fichier `backup-script.conf` avec vos paramètres :
```sh
nano backup-script.conf
```
Lancez le script :
```sh
./backup-script.sh
```

## Les paramètres disponibles
### Dry run
Avec `--dry-run` vous pouvez avoir un aperçu de ce que va faire le script avec de l’exécuter.
### List backup
Avec `--list-backup <CONFIG_RCLONE>` vous pouvez lister les sauvegardes disponibles dans votre stockage externalisé.
### Zabbix send
Avec `--zabbix-send` vous pouvez forcer l'envoi des dernières données récoltées à Zabbix.

## Zabbix
Pour utiliser la supervision des sauvegardes avec Zabbix, vous devez importer et attribuer à votre hote le template `Template_Zabbix_App_BackupScript.xml`.
Le premier envoi des données peut etre long ou être en echec, n'hésitez pas à renouveler avec :
```sh
./backup-script.sh --zabbix-send
```
## Grafana
Vous pouvez importer le template `Template_Grafana_BackupScript.json` directement dans votre instance Grafana. 
Vous devrez modifier la variable `$SERVER` afin d'utiliser le template correctement.


Si mon travail vous a été utile, n'hésitez pas à m'offrir un lait-fraise 😃

[!["Buy Me A Coffee"](https://www.buymeacoffee.com/assets/img/custom_images/orange_img.png)](https://www.buymeacoffee.com/PAPAMICA)
