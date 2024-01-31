#!/bin/bash
# Use this for your user data (script without newlines)
# Installs httpd (Linux 2 version)
sudo yum update -y
sudo yum install -y httpd.x86_64
sudo systemctl start httpd
sudo systemctl enable httpd
echo "Hello World from $(hostname -f)" > /var/www/html/index.html