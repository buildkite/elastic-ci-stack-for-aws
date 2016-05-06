#!/bin/bash -eu

sudo touch /etc/lifecycled
sudo curl -Lf -o /usr/bin/lifecycled \
	https://github.com/lox/lifecycled/releases/download/v1.1.0/lifecycled-linux-x86_64
sudo chmod +x /usr/bin/lifecycled

sudo curl -Lf -o /etc/init/lifecycled.conf \
	https://raw.githubusercontent.com/lox/lifecycled/v1.1.0/init/upstart/lifecycled.conf

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