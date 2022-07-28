#!/bin/bash

FILENAME=$1

LINES=$(cat $FILENAME)

mkdir $2
mkdir /tmp
mkdir $2/download/
cd $2/download/

task(){

	LINE=$1
	i=$2
	outputdir=$3

	echo i: $i

	sleep 3

	mkdir $outputdir/$i
	printf "Crawl... $LINE\n"

	printf $LINE | timeout 1800 gospider -t 1 --concurrent 1 -d 1 --other-source --include-other-source --delay 1 --timeout 120 --js=false --sitemap --depth 2 --robots --blacklist eot,jpg,jpeg,gif,css,tif,tiff,png,ttf,otf,woff,woff2,ico,pdf,svg,txt,mp4,avi,mpeg4,mp3,webm,ogv,gif,jpg,jpeg,png > $outputdir/$i/gospider.txt
	cat $outputdir/$i/gospider.txt | grep -vE 'https?:\/\/.*\.json' | grep -vE 'jquery|bootstrap|ga.js|watch.js|wp-embed|angular|wf\-|recaptcha|gtm.js|google|sweetalert|i18n' | grep -E 'https?:\/\/.*\.js' -o | sort -u > $outputdir/$i/wget.txt

	## lauching wayback with a "js only" mode to reduce execution time
	printf 'Launching Gau with wayback..\n'
	printf $LINE | xargs -I{} echo "{}/*&filter=mimetype:application/javascript&somevar=" | gau -providers wayback -b eot,jpg,jpeg,gif,css,tif,tiff,png,ttf,otf,woff,woff2,ico,pdf,svg,txt,mp4,avi,mpeg4,mp3,webm,ogv,gif,jpg,jpeg,png | tee $outputdir/$i/gau.txt >/dev/null   ##gau
	printf $LINE | xargs -I{} echo "{}/*&filter=mimetype:text/javascript&somevar=" | gau -providers wayback -b eot,jpg,jpeg,gif,css,tif,tiff,png,ttf,otf,woff,woff2,ico,pdf,svg,txt,mp4,avi,mpeg4,mp3,webm,ogv,gif,jpg,jpeg,png | tee -a $outputdir/$i/gau.txt >/dev/null   ##gau

	## if js file parsed from wayback didn't return 200 live, we are generating a URL to see a file's content on wayback's server;
	## it's useless for endpoints discovery but there is a point to search for credentials in the old content; that's what we'll do
	## only wayback as of now
	chmod -R 777 $outputdir/$i/

	printf "Fetching URLs for 404 js files from wayback..\n"
	cat $outputdir/$i/gau.txt | cut -d '?' -f1 | cut -d '#' -f1 | grep '.*\.js$' | sort -u | parallel --gnu -j 2 "/go/jsa/automation/404_js_wayback.sh {}" | tee -a $outputdir/$i/creds_search.txt >/dev/null
	cat $outputdir/$i/wget.txt | cut -d '?' -f1 | cut -d '#' -f1 | grep '.*\.js$' | sort -u | parallel --gnu -j 2 "/go/jsa/automation/404_js_wayback.sh {}" | tee -a $outputdir/$i/creds_search.txt >/dev/null
	## save all endpoints to the file for future processing

	## extracting js files from js files
	printf "Printing deep-level js files..\n"
	cat $outputdir/$i/wget.txt | parallel --gnu --pipe -j 2 "python3 /go/jsa/automation/js_files_extraction.py | tee -a $outputdir/$i/wget.txt"

	printf "wget discovered JS files for local creds scan + webpack + api paths\n"
	sed 's/$/.map/' $outputdir/$i/wget.txt > $outputdir/$i/wgetmap.txt

	cat $outputdir/$i/wget.txt | sed 'p;s/\//-/g' | sed 'N;s/\n/ -O /' | xargs wget -c --no-directories -P '$outputdir/download/' --retry-on-host-error --tries=5 --content-disposition --no-check-certificate --timeout=160 --trust-server-names
	cat $outputdir/$i/creds_search.txt | sed 'p;s/\//-/g' | sed 'N;s/\n/ -O /' | xargs wget -c --no-directories -P '$outputdir/download/' --retry-on-host-error --tries=7 --content-disposition --no-check-certificate --timeout=160 --trust-server-names
	cat $outputdir/$i/wgetmap.txt | sed 'p;s/\//-/g' | sed 'N;s/\n/ -O /' | xargs wget -c --no-directories -P '$outputdir/download/' --retry-on-host-error --tries=5 --content-disposition --no-check-certificate --timeout=160 --trust-server-names

	mkdir $outputdir/$i

	outputurl=${LINE//:/.}
	outputurl=${outputurl//\//.}
	
	python3 /go/webpack/unwebpack_sourcemap.py --make-directory --disable-ssl-verification --detect $LINE $outputdir/$i/$outputurl
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
