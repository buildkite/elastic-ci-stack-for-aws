#!/bin/bash -eu

EC2_AVAIL_ZONE=`curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone`
EC2_REGION="`echo \"$EC2_AVAIL_ZONE\" | sed -e 's:\([0-9][0-9]*\)[a-z]*\$:\\1:'`"

sudo apt-get update -yqq

# cloudformation tools
sudo apt-get -yq install python-setuptools python-pip unzip libwww-perl libdatetime-perl
sudo easy_install https://s3.amazonaws.com/cloudformation-examples/aws-cfn-bootstrap-latest.tar.gz

# aws cli tools
sudo pip install awscli

# cloudwatch tools
wget http://aws-cloudwatch.s3.amazonaws.com/downloads/CloudWatchMonitoringScripts-1.2.1.zip
sudo unzip CloudWatchMonitoringScripts-1.2.1.zip -d /usr/local
sudo chmod +x /usr/local/aws-scripts-mon/*.pl
rm CloudWatchMonitoringScripts-1.2.1.zip

# add cloudwatch to cron
cat << EOF | sudo tee /etc/cron.d/cloudwatch
*/2 * * * * root perl /usr/local/aws-scripts-mon/mon-put-instance-data.pl --mem-util --disk-space-util --disk-path=/ --disk-path=/var/lib/docker --from-cron
EOF

sudo chmod +x /etc/cron.d/cloudwatch