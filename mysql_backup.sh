#!/bin/bash

#########################################################
# Title:        MySQL backup to local machine and AWS S3 bucket with retention policy
# Description:  Create SQL-format backups - set record retention policies on local and S3 files
#
# Author:       WESTLEY G. ANDERSON
# paypal:       paypal.me/westleyanderson
# Contributors:
# Date:         01st JANUARY 2018
# Version:      1.0
# Usage:        $sh ~/.scripts/mysql_backup.sh
#
# MANDITORY:    Fill in the variables next to @param
# Assumptions:
#               AWS S3 Bucket created. https://console.aws.amazon.com/s3
#               AWS S3 Bucket folder created to store backup - optional
#               s3cmd (installed) and configured | s3cmd --configure | sudo yum install s3cmd | brew install s3cmd gpg | source http://s3tools.org/download
#               script location ~/.scripts/mysql_backup.sh - only noted for #Usage above
#               chmod +x ~/.scripts/mysql_backup.sh
#               place shell script in /etc/cron.daily or create custom crontab | crontab -e
########################################################
#Global Variables - only change if not autodetected
########################################################
HOST_NAME=$(hostname)

########################################################
# DATE and TIME - only change if needed
########################################################
DATESTAMP="$(date +".%m.%d.%Y")"                         # date stamp | format .mm.dd.yyyy
DATETIME_EXECUTED="$(date +"%m.%d.%Y %H:%M")"            # Date and time when exectued | format mm.dd.yyyy 13:00
DAYOFYEAR="$(date +%j)"                                  # day of the year (001..366) | format nnn
DAYOFMONTH="$(date +"%d")"                               #day of the month (1-31) | format dd
LASTDAYOFMONTH="$(date -d "-$(date +%d) days month")"  #Last day of the month | format dd
TODAY=$(date +"%m.%d.%Y")                                #Today | format mm.dd.yyyy
DAYOFWEEK="$(date +"%w")"                                # day of week (0..6); 0 is Sunday

########################################################
# Bin Paths - only change if not autodetected
########################################################
MYSQL="$(which mysql)"
MYSQLDUMP="$(which mysqldump)"
CHOWN="$(which chown)"
CHMOD="$(which chmod)"
GZIP="$(which gzip)"
S3CMD="$(which s3cmd)"
MAIL="$(which sendmail)"

########################################################
#MySQL Variables
########################################################
DB_NAME=''                                  # @param Database NAME | to backup all databases use '--all-databases'
DB_USER=''                                  # @param Database USER
DB_PSWD=''                                  # @param Database PASSWORD
DB_HOST='localhost'                         # @param Database HOST
DB_PORT='3306'                              # @param Database PORT

########################################################
#Storage Variable
########################################################
FILENAME="${DB_NAME}${DATESTAMP}.sql.gz"    # @param string $FILENAME  | Filename for the backup with the .sql.gz extention
DUMP_PATH=~/".backups/database/"            # @param string $DUMP_PATH | realative path to local directory to stored backup
S3_BUCKET="s3://bucketname/"                # @param uri $S3_BUCKET    | S3 BUCKET URI "s3://bucketname/"
S3_PATH="backups/database/"                 # @param string $FILENAME  | S3 directory to store backups. | "" for S3 BUCKET root directory | "directory/" |

########################################################
# MYSQLDUMP - Create local dump and remove existing files accroding to Retention Policy
########################################################

RETENTION_POLICY_LOCAL="1"                # @param int     $RETENTION_POLICY_LOCAL set the retention policy | number of files to retain | caution: 0 - all files will be removed
VERSION="local"                           # @param string  $VERSION default:local | ""
echo "STARTING BACKUP"
echo "CONNECTING to DATABASE NAME:${DB_NAME}"

#checking db name and db CONNECTION
if [[ "$DB_PSWD" == '' ]]; then
  mysql --user=${DB_USER}  --host=${DB_HOST} --port=${DB_PORT} ${DB_NAME} -e exit
  if [[ $? == 0 ]]; then
    echo "CONNECTION to DATABASE NAME:${DB_NAME} established"
  else
    echo "ERROR: UNABLE TO CONNECT TO DATABASE NAME:${DB_NAME}"
    echo "Check your MYSQL Credential"
    exit 1;
  fi

else
  mysql --user=${DB_USER} --password=${DB_PSWD} --host=${DB_HOST} --port=${DB_PORT} ${DB_NAME} -e exit
  if [[ $? == 0 ]]; then
      echo "CONNECTION to DATABASE NAME:${DB_NAME} established"
  else
    echo "ERROR: UNABLE TO CONNECT TO DATABASE NAME:${DB_NAME}"
    echo "Check your MYSQL Credential"
    exit 1;
  fi
fi

# mysqldump and gzip
if [[ "$DB_PSWD" == '' ]]; then
  ${MYSQLDUMP} --add-drop-table --lock-tables=true --user=${DB_USER}  --host=${DB_HOST} --port=${DB_PORT} ${DB_NAME}  | ${GZIP} -9 > ${DUMP_PATH}${FILENAME}
else
  ${MYSQLDUMP} --add-drop-table --lock-tables=true --user=${DB_USER} --password=${DB_PSWD} --host=${DB_HOST} --port=${DB_PORT} ${DB_NAME} | ${GZIP} -9 > ${DUMP_PATH}${FILENAME}
fi

# File Size of backup
FILESIZE="$(ls -lah ${DUMP_PATH}${FILENAME} | awk '{print $5}')"
echo "${FILENAME} created and contains ${FILESIZE}"

# Find and remove backups outside of the retention POLICY
echo "RETENTION POLICY - removing [${VERSION}] files outside of retention period"
echo "RETENTION_POLICY_DAILY= no more than ${RETENTION_POLICY_LOCAL} ${VERSION} backups"
find ${DUMP_PATH}/*.sql.gz -mtime +${RETENTION_POLICY_LOCAL} -exec rm {} \;
echo "RETENTION POLICY - succeeded"

########################################################
# S3 Storage Schedule and Retention Policy for Backup Files
########################################################
# BACKUP SCHEDULE - [AUTO] includes [YEARLY] [MONTHLY] [WEEKLY] [DAILY] Backups
BACKUP_SCHEDULE="AUTO"                    # @param [YEARLY] [MONTHLY] [WEEKLY] [DAILY] | [AUTO]

# RETENTION POLICY - set the retention policy | number of files to retain | caution: 0 will removed existing Backups from the POLICY
RETENTION_POLICY_YEARLY="99"              # @param int   $RETENTION_POLICY_YEARLY
RETENTION_POLICY_MONTHLY="11"             # @param int   $RETENTION_POLICY_MONTHLY
RETENTION_POLICY_WEEKLY="5"               # @param int   $RETENTION_POLICY_WEEKLY
RETENTION_POLICY_DAILY="6"                # @param int   $RETENTION_POLICY_DAILY

########################################################
# S3 BUCKET - Transfer(s) and Retention Policy enforcement
########################################################
#TODO Refactor
S3_CONN="CONNECTING TO AMAZON S3"
S3_SEND="SENDING DATA TO AMAZON S3 BUCKET"
S3_SUCCESS="UPLOAD to AMAZON S3 BUCKET - SUCCCEEDED"

case $BACKUP_SCHEDULE in
  AUTO )
  if [[ $DAYOFYEAR > 364
   ]]; then
    VERSION="yearly"
    echo $S3_CONN
    echo $S3_SEND
    ${S3CMD} --acl-private put "${DUMP_PATH}${FILENAME}" "${S3_BUCKET}${S3_PATH}{$VERSION}/"
    echo $S3_SUCCESS
    echo "RETENTION POLICY - removing [${VERSION}] files outside of retention period"
    echo "RETENTION_POLICY_DAILY: no more than ${RETENTION_POLICY_DAILY} ${VERSION} backups"
    ${S3CMD} ls ${S3_BUCKET}${S3_PATH}${VERSION}/ | awk '$1 != "DIR"' | sort -r | awk -v var="${RETENTION_POLICY_YEARLY}" 'NR > var {print $4;}' | xargs --no-run-if-empty s3cmd del
    echo "RETENTION POLICY - succeeded"
  elif [[ $DAYOFMONTH == $LASTDAYOFMONTH ]]; then
    VERSION="monthly"
    echo $S3_CONN
    echo $S3_SEND
    ${S3CMD} --acl-private put "${DUMP_PATH}${FILENAME}" "${S3_BUCKET}${S3_PATH}{$VERSION}"
    echo $S3_SUCCESS
    echo "RETENTION POLICY - removing [${VERSION}] files outside of retention period"
    echo "RETENTION_POLICY_DAILY: no more than ${RETENTION_POLICY_MONTHLY} ${VERSION} backups"
    ${S3CMD} ls ${S3_BUCKET}${S3_PATH}${VERSION}/ | awk '$1 != "DIR"' | sort -r | awk -v var="${RETENTION_POLICY_MONTHLY}" 'NR > var {print $4;}' | xargs --no-run-if-empty s3cmd del
    echo "RETENTION POLICY - succeeded"
  elif [[ $DAYOFWEEK == 0 ]]; then
    VERSION="weekly"
    echo $S3_CONN
    echo $S3_SEND
    ${S3CMD} --acl-private put "${DUMP_PATH}${FILENAME}" "${S3_BUCKET}${S3_PATH}${VERSION}/"
    echo $S3_SUCCESS
    echo "RETENTION POLICY - removing [${VERSION}] files outside of retention period"
    echo "RETENTION_POLICY_DAILY: no more than ${RETENTION_POLICY_WEEKLY} ${VERSION} backups"
    ${S3CMD} ls ${S3_BUCKET}${S3_PATH}${VERSION}/ | awk '$1 != "DIR"' | sort -r | awk -v var="${RETENTION_POLICY_WEEKLY}" 'NR > var {print $4;}' | xargs --no-run-if-empty s3cmd del
    echo "RETENTION POLICY - succeeded"
  elif [[ $DAYOFWEEK != 0 ]]; then
    VERSION="daily"
    echo $S3_CONN
    echo $S3_SEND
    ${S3CMD} --acl-private put "${DUMP_PATH}${FILENAME}" "${S3_BUCKET}${S3_PATH}${VERSION}/"
    echo $S3_SUCCESS
    echo "RETENTION POLICY - removing [${VERSION}] files outside of retention period"
    echo "RETENTION_POLICY_DAILY: no more than ${RETENTION_POLICY_DAILY} ${VERSION} backups"
    ${S3CMD} ls ${S3_BUCKET}${S3_PATH}${VERSION}/ | awk '$1 != "DIR"' | sort -r | awk -v var="${RETENTION_POLICY_DAILY}" 'NR > var {print $4;}' | xargs --no-run-if-empty s3cmd del
    echo "RETENTION POLICY - succeeded"
  else  echo "error: unable to identify backup VERSION"
  fi
    ;;
  YEARLY )
  VERSION="yearly"
  echo $S3_CONN
  echo $S3_SEND
  ${S3CMD} --acl-private put "${DUMP_PATH}${FILENAME}" "${S3_BUCKET}${S3_PATH}${VERSION}/"
  echo $S3_SUCCESS
  echo "RETENTION POLICY - removing [${VERSION}] files outside of retention period"
  echo "RETENTION_POLICY_DAILY: no more than ${RETENTION_POLICY_DAILY} ${VERSION} backups"
  ${S3CMD} ls ${S3_BUCKET}${S3_PATH}${VERSION}/ | awk '$1 != "DIR"' | sort -r | awk -v var="${RETENTION_POLICY_YEARLY}" 'NR > var {print $4;}' | xargs --no-run-if-empty s3cmd del
  echo "RETENTION POLICY - succeeded"
    ;;
  MONTHLY )
  VERSION="monthly"
  echo $S3_CONN
  echo $S3_SEND
  ${S3CMD} --acl-private put "${DUMP_PATH}${FILENAME}" "${S3_BUCKET}${S3_PATH}${VERSION}/"
  echo $S3_SUCCESS
  echo "RETENTION POLICY - removing [${VERSION}] files outside of retention period"
  echo "RETENTION_POLICY_DAILY: no more than ${RETENTION_POLICY_MONTHLY} ${VERSION} backups"
  ${S3CMD} ls ${S3_BUCKET}${S3_PATH}${VERSION}/ | awk '$1 != "DIR"' | sort -r | awk -v var="${RETENTION_POLICY_MONTHLY}" 'NR > var {print $4;}' | xargs --no-run-if-empty s3cmd del
  echo "RETENTION POLICY - succeeded"
    ;;
  WEEKLY )
  VERSION="weekly"
  echo $S3_CONN
  echo $S3_SEND
  ${S3CMD} --acl-private put "${DUMP_PATH}${FILENAME}" "${S3_BUCKET}${S3_PATH}${VERSION}/"
  echo $S3_SUCCESS
  echo "RETENTION POLICY - removing [${VERSION}] files outside of retention period"
  echo "RETENTION_POLICY_DAILY: no more than ${RETENTION_POLICY_WEEKLY} ${VERSION} backups"
  ${S3CMD} ls ${S3_BUCKET}${S3_PATH}${VERSION}/ | awk '$1 != "DIR"' | sort -r | awk -v var="${RETENTION_POLICY_WEEKLY}" 'NR > var {print $4;}' | xargs --no-run-if-empty s3cmd del
  echo "RETENTION POLICY - succeeded"
    ;;
  DAILY )
  VERSION="daily"
  echo $S3_CONN
  echo $S3_SEND
  ${S3CMD} --acl-private put "${DUMP_PATH}${FILENAME}" "${S3_BUCKET}${S3_PATH}${VERSION}/"
  echo $S3_SUCCESS
  echo "RETENTION POLICY - removing [${VERSION}] files outside of retention period"
  echo "RETENTION_POLICY_DAILY: no more than ${RETENTION_POLICY_DAILY} ${VERSION} backups"
  ${S3CMD} ls ${S3_BUCKET}${S3_PATH}${VERSION}/ | awk '$1 != "DIR"' | sort -r | awk -v var="${RETENTION_POLICY_DAILY}" 'NR > var {print $4;}' | xargs --no-run-if-empty s3cmd del
  echo "RETENTION POLICY - succeeded"
    ;;
  *) echo "BACKUP_SCHEDULE not defined"
esac

########################################################
# Email Status Report
########################################################

MAILFROM="admin@example.com>"             # @param string   $MAILFROM "email_address@hostname"
RECIPIENTS="admin@example.com"            # @param string   $RECIPIENTS "email_address@hostname" | "email1_address@hostname,"email2_address@hostname"
RECIPIENTS_NAME="Westley"                 # @param string   $RECIPIENTS_NAME "Name of RECIPIENT"
SUBJECT="MySQL Backup | $HOST_NAME"       # @param string   $SUBJECT  "subject of email"

# Email Message | $? stores ERRORS in script
echo "CRAFTING EMAIL ---"
# message if errors exist
if [ $? -ne 0 ]; then
    MESSAGE_TXT="
    <br />SERVER: ${HOST_NAME}
    <br />DATE: ${DATE_BACKUP}
    <br />DATABASE: ${DB_NAME}
    <br />
    <br />MYSQLDUMP of DATABASE:${DATABASE} into file:${FILENAME} -- FAILED
    <br />
    <br />Thanks,
    <br />SYSTEM ADMIN
    "
    e_status="DATABASE BACKUP ERROR"
    font_color="red"
# message in no errors exist
else
    MESSAGE_TXT="
    <br />SERVER: ${HOST_NAME}
    <br />DATE: ${DATE_BACKUP}
    <br />DATABASE: ${DB_NAME}
    <br />
    <br />MYSQLDUMP of DATABASE:${DATABASE} into file:${FILENAME} -- SUCCCEEDED
    <br />
    <br />Thanks,
    <br />SYSTEM ADMIN
    "
    e_status="DATABASE BACKUP SUCCCEEDED"
    font_color="green"
fi

(
echo "From: ${MAILFROM}"
echo "To: ${RECIPIENTS}"
echo "MIME-Version: 1.0"
echo "Content-Type: multipart/mixed;"
echo ' boundary="BOUNDARY"'
echo "Subject: ${SUBJECT}"
echo ""
echo "This is a MIME-encapsulated message"
echo "--BOUNDARY"
echo "Content-Type: text/plain"
echo ""
echo ""
echo ""
echo "--BOUNDARY"
echo "Content-Type: text/html"
echo ""
echo "<html>
<body bgcolor=''>
<font color='${font_color}'>${e_status}</font>
<br />
${MESSAGE_TXT}
</body>
</html>"
echo "--BOUNDARY"
) | ${MAIL} -t

echo "EMAIL SENT TO: ${RECIPIENTS}"
echo "DATABASE BACKUP --- COMPLETED"
echo "Thanks,"
echo ' __  __ _____             _   _ _____  ______ _____   _____  ____  _   _
|  \/  |  __ \      /\   | \ | |  __ \|  ____|  __ \ / ____|/ __ \| \ | |
| \  / | |__) |    /  \  |  \| | |  | | |__  | |__) | (___ | |  | |  \| |
| |\/| |  _  /    / /\ \ | . ` | |  | |  __| |  _  / \___ \| |  | | . ` |
| |  | | | \ \   / ____ \| |\  | |__| | |____| | \ \ ____) | |__| | |\  |
|_|  |_|_|  \_\ /_/    \_\_| \_|_____/|______|_|  \_\_____/ \____/|_| \_|'

echo ""
