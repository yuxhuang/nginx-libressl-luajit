FROM alpine:3.4
MAINTAINER felix@eworks.io

ARG NGINX_VERSION=1.11.6
ARG LIBRESSL_VERSION=2.4.4

ARG NGINX_DEVEL_KIT_VERSION=0.3.0
ARG LUA_NGINX_MODULE_VERSION=0.10.7
ARG LUAJIT_MAIN_VERSION=2.1.0
ARG LUAJIT_VERSION=2.1.0-beta2
ARG UPSTREAM_HC_VERSION=0.3.0

ARG NGINX_DEVEL_KIT=ngx_devel_kit-${NGINX_DEVEL_KIT_VERSION}
ARG LUA_NGINX_MODULE=lua-nginx-module-${LUA_NGINX_MODULE_VERSION}
ARG UPSTREAM_HC_MODULE=nginx_upstream_check_module-${UPSTREAM_HC_VERSION}
ARG NGINX_ROOT=/etc/nginx
ARG WEB_DIR=/www
ARG GPG_KEYS=A1EB079B8D3EB92B4EBD3139663AF51BD5E4D8D5

ENV LUAJIT_LIB /usr/local/lib
ENV LUAJIT_INC /usr/local/include/luajit-2.1

RUN \
  build_pkgs="build-base linux-headers pcre-dev curl zlib-dev gnupg geoip-dev libxslt-dev perl-dev gd-dev" \
  && runtime_pkgs="ca-certificates pcre zlib gd geoip libxslt libgcc" \
  && apk --no-cache add ${runtime_pkgs} ${build_pkgs} \
  && for key in $GPG_KEYS; do \
        gpg --keyserver ha.pool.sks-keyservers.net --recv-keys "$key"; \
     done \
  && mkdir -p /tmp/luajit \
  && cd /tmp/luajit \
  && curl -L https://luajit.org/download/LuaJIT-${LUAJIT_VERSION}.tar.gz -O \
  && curl -L https://github.com/simpl/ngx_devel_kit/archive/v${NGINX_DEVEL_KIT_VERSION}.tar.gz -o ${NGINX_DEVEL_KIT}.tar.gz \
  && curl -L https://github.com/openresty/lua-nginx-module/archive/v${LUA_NGINX_MODULE_VERSION}.tar.gz -o ${LUA_NGINX_MODULE}.tar.gz \
  && curl -L https://github.com/yaoweibin/nginx_upstream_check_module/archive/v${UPSTREAM_HC_VERSION}.tar.gz -o ${UPSTREAM_HC_MODULE}.tar.gz \
  && tar -xzvf LuaJIT-${LUAJIT_VERSION}.tar.gz && rm LuaJIT-${LUAJIT_VERSION}.tar.gz \
  && tar -xzvf ${NGINX_DEVEL_KIT}.tar.gz && rm ${NGINX_DEVEL_KIT}.tar.gz \
  && tar -xzvf ${LUA_NGINX_MODULE}.tar.gz && rm ${LUA_NGINX_MODULE}.tar.gz \
  && tar -xzvf ${UPSTREAM_HC_MODULE}.tar.gz && rm ${UPSTREAM_HC_MODULE}.tar.gz \
  && cd /tmp/luajit/LuaJIT-${LUAJIT_VERSION} \
  && make -j $(getconf _NPROCESSORS_ONLN) && make install \
  && rm -f $LUAJIT_LIB/libluajit-*.so* \
  && mkdir /tmp/libressl \
  && cd /tmp/libressl \
  && curl -fSL http://ftp.openbsd.org/pub/OpenBSD/LibreSSL/libressl-${LIBRESSL_VERSION}.tar.gz -o libressl.tar.gz \
  && curl -fSL http://ftp.openbsd.org/pub/OpenBSD/LibreSSL/libressl-${LIBRESSL_VERSION}.tar.gz.asc -o libressl.tar.gz.asc \
  && gpg --batch --verify libressl.tar.gz.asc libressl.tar.gz \
  && tar -zxf libressl.tar.gz \
  && mkdir -p /tmp/src \
  && cd /tmp/src \
  && curl -fSL https://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz -o nginx.tar.gz \
  && tar -zxf nginx.tar.gz \
  && cd nginx-*/ \
  && ./configure \
    --user=g \
    --group=r \
    --sbin-path=/usr/sbin/nginx \
    --with-cc-opt='-O3 -s' \
    --with-ld-opt='-Wl,-static,-lluajit-5.1 -Wl,-Bdynamic,-ldl,-lz' \
    --with-http_ssl_module \
    --with-openssl=/tmp/libressl/libressl-${LIBRESSL_VERSION} \
    --with-http_realip_module \
    --with-http_addition_module \
    --with-http_sub_module \
    --with-http_dav_module \
    --with-http_flv_module \
    --with-http_mp4_module \
    --with-http_gunzip_module \
    --with-http_gzip_static_module \
    --with-http_random_index_module \
    --with-http_secure_link_module \
    --with-http_stub_status_module \
    --with-http_auth_request_module \
    --with-http_image_filter_module \
    --with-http_xslt_module \
    --with-http_geoip_module \
    --with-mail \
    --with-mail_ssl_module \
    --with-ipv6 \
    --with-http_v2_module \
    --prefix=/etc/nginx \
    --http-log-path=/var/log/nginx/access.log \
    --error-log-path=/var/log/nginx/error.log \
    --add-module=/tmp/luajit/$UPSTREAM_HC_MODULE \
    --add-module=/tmp/luajit/$NGINX_DEVEL_KIT \
    --add-module=/tmp/luajit/$LUA_NGINX_MODULE \
  && make -j $(getconf _NPROCESSORS_ONLN) \
  && make install \
  && make clean \
  && rm -rf /tmp/ /root/.gnupg \
  && rm -rf $LUAJIT_LIB/libluajit-5.1.a \
  && rm -rf $LUAJIT_INC \
  && strip -s /usr/sbin/nginx \
  && apk --no-cache del ${build_pkgs} \
  && apk --no-cache add ${runtime_pkgs} \
  && ln -sf /dev/stdout /var/log/nginx/access.log \
  && ln -sf /dev/stderr /var/log/nginx/error.log


# ***** CLEANUP *****
EXPOSE 80 443

ADD entry.sh /

ENTRYPOINT ["/entry.sh"]

