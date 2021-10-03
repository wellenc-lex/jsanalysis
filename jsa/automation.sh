#!/bin/bash

mkdir ../tmp

printf "Crawl..\n"

printf $1 | timeout 100000 gospider -t 1 --concurrent 3 -d 1 --other-source --include-other-source --delay 1 --timeout 5 --sitemap --robots --blacklist eot,jpg,jpeg,gif,css,tif,tiff,png,ttf,otf,woff,woff2,ico,pdf,svg,txt > ../tmp/gospider.txt
cat ../tmp/gospider.txt | grep -vE 'https?:\/\/.*\.json' | grep -vE 'jquery|bootstrap|ga.js|watch.js|wp-embed|angular|wf\-|recaptcha|gtm.js|google|sweetalert' | grep -E 'https?:\/\/.*\.js' -o | sort -u > ../tmp/wget.txt

## lauching wayback with a "js only" mode to reduce execution time
printf 'Launching Gau with wayback..\n'
printf $1 | xargs -I{} echo "{}/*&filter=mimetype:application/javascript&somevar=" | gau -providers wayback -b ttf,woff,svg,png,jpg,png,jpeg | tee ../tmp/gau.txt >/dev/null   ##gau
printf $1 | xargs -I{} echo "{}/*&filter=mimetype:text/javascript&somevar=" | gau -providers wayback -b ttf,woff,svg,png,jpg,png,jpeg | tee -a ../tmp/gau.txt >/dev/null   ##gau

## if js file parsed from wayback didn't return 200 live, we are generating a URL to see a file's content on wayback's server;
## it's useless for endpoints discovery but there is a point to search for credentials in the old content; that's what we'll do
## only wayback as of now

printf "Fetching URLs for 404 js files from wayback..\n"
cat ../tmp/gau.txt | cut -d '?' -f1 | cut -d '#' -f1 | sort -u | parallel --gnu -j 5 "automation/404_js_wayback.sh {}" | tee -a ../tmp/creds_search.txt >/dev/null
cat ../tmp/wget.txt | cut -d '?' -f1 | cut -d '#' -f1 | sort -u | parallel --gnu -j 5 "automation/404_js_wayback.sh {}" | tee -a ../tmp/creds_search.txt >/dev/null
## save all endpoints to the file for future processing

## extracting js files from js files
printf "Printing deep-level js files..\n"
cat ../tmp/wget.txt | parallel --gnu --pipe -j 5 "python3 automation/js_files_extraction.py | tee -a ../tmp/wget.txt"

printf "wget discovered JS files for local creds scan + webpack + api paths\n"
mkdir ../tmp/download/
cd ../tmp/download/ && cat ../wget.txt | parallel --gnu -j 5 "xargs wget -nc {}" #download .js files
cat ../creds_search.txt | parallel --gnu -j 5 "xargs wget -nc {}" #download .js files

sed 's/$/.map/' ../wget.txt > ../wgetmap.txt

cat ../wgetmap.txt | parallel --gnu --pipe -j 5 "xargs wget -nc" #download .js.map files

mkdir /jsa/$2/
pwd
ls -la

if [ -f "/jsa/shasums" ];
then
    echo "shasums exists"
else
    touch /jsa/shasums
fi

#get sha sum for each file and verify that it havnt been scaned earlier
for filename in *; do
    currentfilehash=$(cat $filename | sha1sum | head -c 40)

	if grep -Fxq "$currentfilehash" /jsa/shasums
	then
	    rm $filename
	else
	    echo "$currentfilehash" >> /jsa/shasums
	fi    
done

find . -iname '*' -maxdepth 1 -exec python3 ../../secretfinder/SecretFinder.py -i {} -o /jsa/$2/secretfinder.html \;






#unbeautify / jsbeautify jsa/tmp/download

#divedumpster

#python3 ../../linkfinder/linkfinder.py -i '*.js' -o /jsa/$2/linkfinder.html  #too much noise. prefer burp suite's linkfinder

#python3 webpack/unwebpack_sourcemap.py --make-directory --disable-ssl-verification --detect $stdin tmp/webpackout



