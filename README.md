mysql-backup

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
