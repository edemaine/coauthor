#!/bin/sh
cd "`dirname "$0"`"
ssh ubuntu@coauthor mongodump --db coauthor
rsync -a ubuntu@coauthor:dump/coauthor/ coauthor-backup/
acd_cli sync
acd_cli mkdir /coauthor-backup/`date +%Y-%m-%d`
count=0
limit=20
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
