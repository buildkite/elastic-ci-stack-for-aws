#!/bin/bash -eu

EC2_AVAIL_ZONE=`curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone`
EC2_REGION="`echo \"$EC2_AVAIL_ZONE\" | sed -e 's:\([0-9][0-9]*\)[a-z]*\$:\\1:'`"

# cloudformation tools
sudo apt-get -y install python-setuptools unzip libwww-perl libdatetime-perl
sudo easy_install https://s3.amazonaws.com/cloudformation-examples/aws-cfn-bootstrap-latest.tar.gz

# cloudwatch tools
wget http://aws-cloudwatch.s3.amazonaws.com/downloads/CloudWatchMonitoringScripts-1.2.1.zip
sudo unzip CloudWatchMonitoringScripts-1.2.1.zip -d /usr/local
sudo chmod +x /usr/local/aws-scripts-mon/*.pl
rm CloudWatchMonitoringScripts-1.2.1.zip

# cloudwatch logs setup
wget https://s3.amazonaws.com/aws-cloudwatch/downloads/latest/awslogs-agent-setup.py
sudo mv awslogs-agent-setup.py /usr/local/bin/awslogs-agent-setup.py
sudo chmod +x /usr/local/bin/awslogs-agent-setup.py
sudo /usr/local/bin/awslogs-agent-setup.py -n -r $EC2_REGION -c /tmp/conf/awslogs.conf