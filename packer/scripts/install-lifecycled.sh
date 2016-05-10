#!/bin/bash -eu

LIFECYCLED_VERSION=v1.1.2

sudo touch /etc/lifecycled
sudo curl -Lf -o /usr/bin/lifecycled \
	https://github.com/lox/lifecycled/releases/download/${LIFECYCLED_VERSION}/lifecycled-linux-x86_64
sudo chmod +x /usr/bin/lifecycled

sudo curl -Lf -o /etc/init/lifecycled.conf \
	https://raw.githubusercontent.com/lox/lifecycled/${LIFECYCLED_VERSION}/init/upstart/lifecycled.conf

cat << EOF | sudo tee /usr/bin/buildkite-lifecycle-handler
#!/bin/sh -eu
echo "stopping buildkite-agent gracefully"
service buildkite-agent stop
while pgrep buildkite-agent > /dev/null; do
  sleep 0.5
done
echo "buildkite-agent stopped!"
EOF

sudo chmod +x /usr/bin/buildkite-lifecycle-handler