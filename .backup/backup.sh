#!/bin/sh
## Trigger mongodump on the server (given by $REMOTE) and copy dump here
## and optionally to the cloud.
##
## You'll obviously first need to install mongodump on the server.
## On Ubuntu: sudo apt-get install mongodb-clients
## On Debian: sudo apt-get install mongo-tools

REMOTE=ubuntu@coauthor

cd "`dirname "$0"`"
ssh $REMOTE mongodump --db coauthor
rsync -a $REMOTE:dump/coauthor/ coauthor-backup/

## rclone is the recommended system to copy backups to a cloud service.
## Just setup a remote called `coauthor-backup` using `rclone config`.
## (acd_cli is another option, but it sadly was turned off by Amazon.)

method=rclone
#method=acd_cli

case $method in

rclone)
  if rclone copy coauthor-backup coauthor-backup:coauthor-backup/`date +%Y-%m-%d`
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
  acd_cli mkdir /coauthor-backup/`date +%Y-%m-%d`
  while ! acd_cli ul -q -o coauthor-backup/* /coauthor-backup/`date +%Y-%m-%d`
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
