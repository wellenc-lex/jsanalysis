FROM golang:latest

COPY . .

ENV HOME /go/jsa
ENV GOPATH=/go/
ENV PATH $PATH:$GOPATH
ENV PATH $PATH:/go/jsa

WORKDIR /go/jsa/

RUN apt -y update && apt -y install git  	\
				    wget 	\
				    python3 	\
				    python3-pip parallel && rm -rf /var/lib/apt/lists/*

RUN GO111MODULE=on go get -u -v github.com/lc/gau && GO111MODULE=on go get -u github.com/jaeles-project/gospider

RUN pip3 install idna==2.10 && pip3 install tldextract && pip3 install -r /go/linkfinder/requirements.txt

RUN chmod +x automation.sh && chmod +x automation/404_js_wayback.sh

ENTRYPOINT ["automation.sh"]

