#!/bin/bash

apt-get update -y && apt-get upgrade -y
apt-get install -y nginx
echo "Hello World 1" | sudo tee -a /var/www/html/index.html
