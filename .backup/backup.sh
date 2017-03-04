#!/bin/sh
cd "`dirname "$0"`"
ssh ubuntu@coauthor mongodump --db coauthor
rsync -a ubuntu@coauthor:dump/coauthor/ coauthor-backup/
acd_cli sync
acd_cli mkdir /coauthor-backup/`date +%Y-%m-%d`
count=0
while ! acd_cli ul -q -o coauthor-backup/* /coauthor-backup/`date +%Y-%m-%d`
do
  echo Trying again... $count
  acd_cli sync
  acd_cli ul -q -o coauthor-backup/* /coauthor-backup/`date +%Y-%m-%d`
  count=`expr $count + 1`
  if [ $count > 20 ]
  then
    break
  fi
done
