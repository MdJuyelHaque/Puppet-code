#!/bin/bash
YESTERDAY=`date -d "yesterday 13:00" '+%Y-%m-%d'`
/bin/gzip -1f $1/*.${YESTERDAY}.log
/bin/gzip -1f $1/*.${YESTERDAY}.txt
