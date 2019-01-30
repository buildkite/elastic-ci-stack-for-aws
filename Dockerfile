FROM frolvlad/alpine-glibc:latest
# Need glibc for the iamy binary

RUN apk --update add bash coreutils ansible nodejs nodejs-npm ruby-bundler \
                     curl make \
                     ruby-dev build-base \
                     py-pip git \
                     ca-certificates \
                     openssh-client \
                     unzip vim groff

ADD https://github.com/joffotron/aws-kms/releases/download/v0.1.0/aws-kms-linux-amd64 /usr/bin/aws-kms

ADD https://releases.hashicorp.com/packer/1.3.1/packer_1.3.1_linux_amd64.zip /tmp/
RUN unzip /tmp/packer_1.3.1_linux_amd64.zip && mv packer /usr/bin/packer

ADD https://github.com/lox/parfait/releases/download/v1.1.3/parfait_linux_amd64 /usr/bin/parfait

RUN chmod a+x /usr/bin/parfait /usr/bin/packer /usr/bin/aws-kms

RUN pip install --upgrade pip && pip install awscli

RUN mkdir /buildkite-ci/
WORKDIR /buildkite-ci/
COPY . /buildkite-ci/

CMD ["/bin/bash"]
