FROM jimho/lua

## Install Luarocks
ENV LUAROCKS_VERSION 2.4.2
ENV LUAROCKS_INSTALL luarocks-$LUAROCKS_VERSION
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

## Install PuRest

# yum-plugin-ovl is needed to fix issues with yum in centos container
RUN yum install -y yum-plugin-ovl && yum clean all

RUN curl https://packages.microsoft.com/config/rhel/7/prod.repo | tee /etc/yum.repos.d/microsoft.repo
RUN yum install -y gcc-c++ openssl git powershell && yum clean all

WORKDIR /usr/local/bin

RUN git clone https://github.com/djfdyuruiry/PuRest

WORKDIR /

RUN /usr/local/bin/PuRest/scripts/installLuaDependencies.sh
RUN pwsh /usr/local/bin/PuRest/build.ps1

ENTRYPOINT [ "pwsh", "/usr/local/bin/PuRest/build/release/startServer.ps1" ]

EXPOSE 8888 8888
EXPOSE 4430 4430
