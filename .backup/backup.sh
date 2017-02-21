#!/bin/sh
cd "`dirname "$0"`"
ssh ubuntu@coauthor mongodump --db coauthor
rsync -a ubuntu@coauthor:dump/coauthor/ coauthor-backup/
acd_cli mkdir /coauthor-backup/`date +%Y-%m-%d`
acd_cli ul coauthor-backup/* /coauthor-backup/`date +%Y-%m-%d`
