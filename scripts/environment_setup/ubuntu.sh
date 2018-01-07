#!/bin/bash
set -e

## install system utils
sudo apt-get update
sudo apt-get -y install curl apt-transport-https tar

## register the ms ubuntu repo
curl https://packages.microsoft.com/keys/microsoft.asc | sudo apt-key add -

UBUNTU_VERSION=$(echo $(lsb_release -r) | sed 's/Release: //g')

curl "https://packages.microsoft.com/config/ubuntu/$UBUNTU_VERSION/prod.list" | sudo tee /etc/apt/sources.list.d/microsoft.list

## install packages needed by lua, luarocks and PuRest
sudo apt-get update
sudo apt-get -y install build-essential unzip git \
    openssl libssl-dev  \
    libreadline6-dev libpcre3-dev \
    powershell

## install lua & luarocks
curl -L http://www.lua.org/ftp/lua-5.3.4.tar.gz | tar xzf - && \
    cd lua-5.3.4 && \
    make linux test && \
    sudo make install && \
    cd .. && rm lua-5.3.4 -r

curl -L https://luarocks.org/releases/luarocks-2.4.2.tar.gz | tar xzf - && \
    cd luarocks-2.4.2 && \
    ./configure && \
    make build && \
    sudo make install && \
    cd .. && rm luarocks-2.4.2 -r

## install PuRest lua dependencies
curl https://raw.githubusercontent.com/djfdyuruiry/PuRest/master/scripts/installLuaDependencies.ps1 | sudo pwsh -Command -
