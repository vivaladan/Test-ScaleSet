#!/bin/bash

wget https://packages.microsoft.com/config/ubuntu/18.04/packages-microsoft-prod.deb -O packages-microsoft-prod.deb
sudo dpkg -i packages-microsoft-prod.deb

apt-get update -y && apt-get upgrade -y
apt-get install -y nginx apt-transport-https aspnetcore-runtime-3.1

echo "Hello World $1" | sudo tee -a /var/www/html/index.html
