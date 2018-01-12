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
Copyright 2018 

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
