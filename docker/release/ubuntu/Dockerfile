FROM ubuntu:17.04

ENV LUA_VERSION 5.3.4
ENV LUAROCKS_VERSION 2.4.2
ENV LUAROCKS_INSTALL luarocks-$LUAROCKS_VERSION

## install system utils
RUN apt-get update
RUN yes | apt-get install curl apt-transport-https tar unzip

## register the ms ubuntu repo
RUN curl https://packages.microsoft.com/keys/microsoft.asc | \
    apt-key add -

RUN curl https://packages.microsoft.com/config/ubuntu/17.04/prod.list | \
    tee /etc/apt/sources.list.d/microsoft.list

## install packages needed by lua, luarocks and PuRest
RUN apt-get update
RUN yes | apt-get install build-essential git \
                          openssl libssl-dev  \
                          libreadline6-dev libpcre3-dev \
                          powershell

## install lua
RUN curl -L http://www.lua.org/ftp/lua-${LUA_VERSION}.tar.gz | tar xzf - && \
    cd /lua-$LUA_VERSION && \
    make linux test && \
    make install && \
    cd .. && rm /lua-$LUA_VERSION -r

## install Luarocks
ENV TMP_LOC /tmp/luarocks

RUN curl -OL https://luarocks.org/releases/${LUAROCKS_INSTALL}.tar.gz && \
    tar xzf $LUAROCKS_INSTALL.tar.gz && \
    mv $LUAROCKS_INSTALL $TMP_LOC && \
    rm $LUAROCKS_INSTALL.tar.gz

WORKDIR $TMP_LOC

RUN ./configure && \
    make build && \
    make install

WORKDIR /

RUN rm $TMP_LOC -rf

## install PuRest
WORKDIR /usr/local/bin

RUN git clone https://github.com/djfdyuruiry/PuRest

WORKDIR /

RUN /usr/local/bin/PuRest/scripts/installLuaDependencies.sh
RUN pwsh /usr/local/bin/PuRest/build.ps1

ENTRYPOINT [ "pwsh", "/usr/local/bin/PuRest/build/release/startServer.ps1" ]

EXPOSE 8888 8888
EXPOSE 4430 4430
