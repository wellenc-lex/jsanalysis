#!/bin/bash

url=$1

status_code=$(curl --insecure --connect-timeout 100 -sL -w "%{http_code}" $url -o /dev/null)

if [ $status_code != "200" ]
then
printf "https://web.archive.org/web/20060102150405if_/$url\n"
fi
