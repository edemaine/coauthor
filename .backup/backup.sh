#!/bin/sh
## Trigger mongodump on the server (given by $REMOTE) and copy dump here
## and optionally to the cloud.
##
## You'll obviously first need to install mongodump on the server.
## On Ubuntu: sudo apt-get install mongodb-clients
## On Debian: sudo apt-get install mongo-tools

## Where to ssh to do the mongodump
HOSTNAME=coauthor
USERNAME=ubuntu
#USERNAME=root
SSH_REMOTE=$USERNAME@$HOSTNAME

## Mongo database to dump
MONGO_DB=coauthor

## Local backup directory name
BACKUP_DIR=coauthor-backup

## rclone is the recommended system to copy backups to a cloud service.
## (acd_cli is another option, but it sadly was turned off by Amazon.)
METHOD=rclone
#METHOD=acd_cli

## 1 for a separate backup for each day; 0 to overwrite the backup each time
DATE_IN_DIR=0
if [ "$DATE_IN_DIR" -eq 1 ]
then
  datedir=/`date +%Y-%m-%d`
else
  datedir=
fi

## Set up an rclone remote with this name using `rclone config`.
CLOUD_REMOTE=coauthor-backup

## Directory to create on cloud remote.
CLOUD_DIR="coauthor-backup$datedir"

cd "`dirname "$0"`"
echo \* mongodump
ssh "$SSH_REMOTE" mongodump --db "$MONGO_DB" --gzip
echo \* rsync
rsync -e ssh -a "$SSH_REMOTE:dump/$MONGO_DB/" "$BACKUP_DIR/"

echo \* $METHOD

case $METHOD in

rclone)
  if rclone --retries 10 copy "$BACKUP_DIR" $CLOUD_REMOTE:$CLOUD_DIR
  then
    echo SUCCESS\!\!
  else
    echo FAILURE...
  fi
  ;;

acd_cli)
  count=0
  limit=20
  acd_cli sync
  acd_cli mkdir /$CLOUD_DIR
  while ! acd_cli ul -q -o "$BACKUP_DIR"/* /${CLOUD_DIR}
  do
    echo Trying again... $count
    acd_cli sync
    count=`expr $count + 1`
    if [ $count -gt $limit ]
    then
      break
    fi
  done
  if [ $count -le $limit ]
  then
    echo SUCCESS\!\!
  fi
  ;;

esac
