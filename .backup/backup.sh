#!/bin/sh
cd "`dirname "$0"`"
ssh ubuntu@coauthor mongodump --db coauthor
rsync -a ubuntu@coauthor:dump/coauthor/ latest
