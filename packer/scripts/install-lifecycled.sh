#!/bin/bash -eu

touch /etc/lifecycled

curl -Lf -o /usr/bin/lifecycled \
	https://github.com/lox/lifecycled/releases/download/v1.0.0/lifecycled-linux-x86_64
chmod +x /usr/bin/lifecycled

curl -Lf -o /etc/init/lifecycled.conf \
	https://raw.githubusercontent.com/lox/lifecycled/v1.0.0/init/upstart/lifecycled.conf