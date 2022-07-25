Automatic crawl domain for js files, search .js files in waybackmachine + gau

Find sensitive strings, credentials, apikeys in crawled JS files with trufflehog.

Just works. 

Example usage:

docker run --dns=8.8.8.8 --rm --privileged=true --ulimit nofile=1048576:1048576 --cpu-shares 256 -v jsa:/jsa 5631/jsa /jsa/URLINPUT.txt /jsa/OUTPUTDIRECTORY >> /jsa/jsa.output

