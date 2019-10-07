FROM amazonlinux:2

RUN yum install -y git

RUN git clone https://github.com/bats-core/bats-core.git \
    && cd bats-core \
    && git checkout v1.1.0 \
    && ./install.sh /usr/local

CMD [ "bash", "/usr/local/bin/bats", "/src/unit-tests/*.bats"]
