#!/bin/bash

url=$1

status_code=$(curl --insecure -sL -w "%{http_code}\n" $url -o /dev/null)

if [ $status_code != "200" ]
then
printf "https://web.archive.org/web/20060102150405if_/$url\n"
fi
