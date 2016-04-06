FROM golang:1.6

RUN apt-get update -yqq \
	&& apt-get install -y build-essential python-pip unzip ruby \
	&& pip install awscli \
	&& gem install bundler cfoo

RUN wget https://releases.hashicorp.com/packer/0.8.6/packer_0.8.6_linux_amd64.zip \
	&& unzip packer_0.8.6_linux_amd64.zip -d /usr/local/bin/