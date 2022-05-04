#!/bin/bash

FILENAME=$1

LINES=$(cat $FILENAME)

mkdir /tmp
mkdir /tmp/download/
cd /tmp/download/

mkdir $2

task(){

	LINE=$1
	i=$2
	outputdir=$3

	echo i: $i

	mkdir /tmp/$i
	printf "Crawl... $LINE\n"

	printf $LINE | timeout 2200 gospider -t 1 --concurrent 1 -d 1 --other-source --include-other-source --delay 1 --timeout 160 --js=false --sitemap --depth 2 --robots --blacklist eot,jpg,jpeg,gif,css,tif,tiff,png,ttf,otf,woff,woff2,ico,pdf,svg,txt,mp4,avi,mpeg4,mp3,webm,ogv,gif,jpg,jpeg,png > /tmp/$i/gospider.txt
	cat /tmp/$i/gospider.txt | grep -vE 'https?:\/\/.*\.json' | grep -vE 'jquery|bootstrap|ga.js|watch.js|wp-embed|angular|wf\-|recaptcha|gtm.js|google|sweetalert' | grep -E 'https?:\/\/.*\.js' -o | sort -u > /tmp/$i/wget.txt

	## lauching wayback with a "js only" mode to reduce execution time
	printf 'Launching Gau with wayback..\n'
	printf $LINE | xargs -I{} echo "{}/*&filter=mimetype:application/javascript&somevar=" | gau -providers wayback -b eot,jpg,jpeg,gif,css,tif,tiff,png,ttf,otf,woff,woff2,ico,pdf,svg,txt,mp4,avi,mpeg4,mp3,webm,ogv,gif,jpg,jpeg,png | tee /tmp/$i/gau.txt >/dev/null   ##gau
	printf $LINE | xargs -I{} echo "{}/*&filter=mimetype:text/javascript&somevar=" | gau -providers wayback -b eot,jpg,jpeg,gif,css,tif,tiff,png,ttf,otf,woff,woff2,ico,pdf,svg,txt,mp4,avi,mpeg4,mp3,webm,ogv,gif,jpg,jpeg,png | tee -a /tmp/$i/gau.txt >/dev/null   ##gau

	## if js file parsed from wayback didn't return 200 live, we are generating a URL to see a file's content on wayback's server;
	## it's useless for endpoints discovery but there is a point to search for credentials in the old content; that's what we'll do
	## only wayback as of now
	chmod -R 777 /tmp/$i/

	printf "Fetching URLs for 404 js files from wayback..\n"
	cat /tmp/$i/gau.txt | cut -d '?' -f1 | cut -d '#' -f1 | grep '.*\.js$' | sort -u | parallel --gnu -j 2 "/go/jsa/automation/404_js_wayback.sh {}" | tee -a /tmp/$i/creds_search.txt >/dev/null
	cat /tmp/$i/wget.txt | cut -d '?' -f1 | cut -d '#' -f1 | grep '.*\.js$' | sort -u | parallel --gnu -j 2 "/go/jsa/automation/404_js_wayback.sh {}" | tee -a /tmp/$i/creds_search.txt >/dev/null
	## save all endpoints to the file for future processing

	## extracting js files from js files
	printf "Printing deep-level js files..\n"
	cat /tmp/$i/wget.txt | parallel --gnu --pipe -j 2 "python3 /go/jsa/automation/js_files_extraction.py | tee -a /tmp/$i/wget.txt"

	printf "wget discovered JS files for local creds scan + webpack + api paths\n"
	sed 's/$/.map/' /tmp/$i/wget.txt > /tmp/$i/wgetmap.txt

	cat /tmp/$i/wget.txt | sed 'p;s/\//-/g' | sed 'N;s/\n/ -O /' | xargs wget -c --no-directories -P '/tmp/download/' --retry-on-host-error --tries=3 --content-disposition --no-check-certificate --timeout=120 --trust-server-names
	cat /tmp/$i/creds_search.txt | sed 'p;s/\//-/g' | sed 'N;s/\n/ -O /' | xargs wget -c --no-directories -P '/tmp/download/' --retry-on-host-error --tries=3 --content-disposition --no-check-certificate --timeout=120 --trust-server-names
	cat /tmp/$i/wgetmap.txt | sed 'p;s/\//-/g' | sed 'N;s/\n/ -O /' | xargs wget -c --no-directories -P '/tmp/download/' --retry-on-host-error --tries=3 --content-disposition --no-check-certificate --timeout=120 --trust-server-names

	mkdir $outputdir/$i

	python3 /go/webpack/unwebpack_sourcemap.py --make-directory --disable-ssl-verification --detect $LINE $outputdir/$i/webpackout
}

i=0
for LINE in $LINES
do   
	((i=i+1))
	task "$LINE" "$i" "$2" & #call all domains in parallel
done

wait
pwd

if [ ! -f "/jsa/shasums" ];
then
    touch /jsa/shasums
fi

#get sha sum for each file and verify that it havnt been scaned earlier
for filename in *
do
    currentfilehash=$(cat "$filename" | sha1sum | head -c 40)

	if grep -Fxq "$currentfilehash" /jsa/shasums
	then
	    rm "$filename"
	else
	    echo "$currentfilehash" >> /jsa/shasums
	fi    
done

trufflehog filesystem --directory=$2 >> $2/out.txt
trufflehog filesystem --directory=/tmp/download/ >> $2/out.txt
