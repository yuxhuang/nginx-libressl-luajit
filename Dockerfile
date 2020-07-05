FROM alpine:3.12
MAINTAINER felix@eworks.io

ARG NGINX_VERSION=1.18.0
ARG LIBRESSL_VERSION=3.1.3

ARG NGINX_DEVEL_KIT_VERSION=0.3.1
ARG LUA_NGINX_MODULE_VERSION=0.10.15
ARG LUAJIT_MAIN_VERSION=2.1.0
ARG LUAJIT_VERSION=2.1.0-beta3
ARG NGINX_RTMP_MODULE_VERSION=1.2.1
ARG UPSTREAM_HC_VERSION=master
ARG QUICHE_VERSION=147bdf95a784eaaaaffe66d7a1fef505f516ddf3

ARG NGINX_DEVEL_KIT=ngx_devel_kit-${NGINX_DEVEL_KIT_VERSION}
ARG LUA_NGINX_MODULE=lua-nginx-module-${LUA_NGINX_MODULE_VERSION}
ARG UPSTREAM_HC_MODULE=nginx_upstream_check_module-${UPSTREAM_HC_VERSION}
ARG NGINX_RTMP_MODULE=nginx-rtmp-module-${NGINX_RTMP_MODULE_VERSION}
ARG NGINX_ROOT=/etc/nginx
ARG WEB_DIR=/www
ARG GPG_KEYS=A1EB079B8D3EB92B4EBD3139663AF51BD5E4D8D5

ARG build_pkgs="build-base linux-headers pcre-dev curl zlib-dev geoip-dev libxslt-dev perl-dev gd-dev unzip cmake cargo rust git libunwind-dev go"
ARG runtime_pkgs="ca-certificates pcre zlib gd geoip libxslt libgcc certbot certbot-nginx"

ENV LUAJIT_LIB /usr/local/lib
ENV LUAJIT_INC /usr/local/include/luajit-2.1

ADD https://luajit.org/download/LuaJIT-${LUAJIT_VERSION}.tar.gz /tmp/luajit/
ADD https://github.com/simpl/ngx_devel_kit/archive/v${NGINX_DEVEL_KIT_VERSION}.tar.gz /tmp/luajit/${NGINX_DEVEL_KIT}.tar.gz
#ADD https://github.com/openresty/lua-nginx-module/archive/v${LUA_NGINX_MODULE_VERSION}.tar.gz /tmp/luajit/${LUA_NGINX_MODULE}.tar.gz
ADD https://github.com/yaoweibin/nginx_upstream_check_module/archive/${UPSTREAM_HC_VERSION}.tar.gz /tmp/luajit/${UPSTREAM_HC_MODULE}.tar.gz
ADD https://github.com/arut/nginx-rtmp-module/archive/v${NGINX_RTMP_MODULE_VERSION}.tar.gz /tmp/luajit/${NGINX_RTMP_MODULE}.tar.gz
ADD https://cloudflare.cdn.openbsd.org/pub/OpenBSD/LibreSSL/libressl-${LIBRESSL_VERSION}.tar.gz /tmp/libressl/libressl.tar.gz
ADD https://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz /tmp/src/nginx.tar.gz

RUN apk --no-cache add ${runtime_pkgs} ${build_pkgs}

RUN cd /tmp/luajit \
  && tar -xzvf LuaJIT-${LUAJIT_VERSION}.tar.gz && rm LuaJIT-${LUAJIT_VERSION}.tar.gz \
  && tar -xzvf ${NGINX_DEVEL_KIT}.tar.gz && rm ${NGINX_DEVEL_KIT}.tar.gz \
  #&& tar -xzvf ${LUA_NGINX_MODULE}.tar.gz && rm ${LUA_NGINX_MODULE}.tar.gz \
  && tar -xzvf ${UPSTREAM_HC_MODULE}.tar.gz && rm ${UPSTREAM_HC_MODULE}.tar.gz \
  && tar -xzvf ${NGINX_RTMP_MODULE}.tar.gz && rm ${NGINX_RTMP_MODULE}.tar.gz \
  && cd /tmp/luajit/LuaJIT-${LUAJIT_VERSION} \
  && make -j $(getconf _NPROCESSORS_ONLN) && make install \
  && rm -f $LUAJIT_LIB/libluajit-*.so* \
  && cd /tmp/libressl \
  && tar -zxf libressl.tar.gz \
  && cd /tmp/src \
  && tar -zxf nginx.tar.gz

RUN cd /tmp/src \
  && git clone --recursive https://github.com/cloudflare/quiche \
  && cd quiche \
  && git checkout ${QUICHE_VERSION}

RUN cd /tmp/src/nginx-*/ \
  && patch -p0 /tmp/luajit/${UPSTREAM_HC_MODULE}/check_1.14.0+.patch \
  && patch --verbose -p01 < ../quiche/extras/nginx/nginx-1.16.patch

RUN cd /tmp/src/nginx-* \
    && CFLAGS="-Wno-implicit-fallthrough" ./configure \
    --with-cc-opt="-Wno-implicit-fallthrough" \
    --user=g \
    --group=r \
    --sbin-path=/usr/sbin/nginx \
    --with-cc-opt='-O3 -s' \
    --with-ld-opt='-Wl,-static,-lluajit-5.1 -Wl,-Bdynamic,-ldl,-lz' \
    --with-http_ssl_module \
 #   --with-openssl=/tmp/libressl/libressl-${LIBRESSL_VERSION} \
    --with-openssl=../quiche/deps/boringssl \
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
    --with-http_v3_module \
    --build="quiche-$(git --git-dir=../quiche/.git rev-parse --short HEAD)" \
    --with-quiche=../quiche \
    --prefix=/etc/nginx \
    --http-log-path=/var/log/nginx/access.log \
    --error-log-path=/var/log/nginx/error.log \
    --add-module=/tmp/luajit/$UPSTREAM_HC_MODULE \
    --add-module=/tmp/luajit/$NGINX_DEVEL_KIT \
    #--add-module=/tmp/luajit/$LUA_NGINX_MODULE \
    --add-module=/tmp/luajit/${NGINX_RTMP_MODULE} \
  && make -j $(getconf _NPROCESSORS_ONLN) \
  && make install \
  && make clean \
  && rm -rf /tmp/ /root/.gnupg \
  && rm -rf $LUAJIT_LIB/libluajit-5.1.a \
  && rm -rf $LUAJIT_INC \
  && strip -s /usr/sbin/nginx

RUN \
  apk --no-cache del ${build_pkgs} \
  && apk --no-cache add ${runtime_pkgs}

RUN ln -sf /dev/stdout /var/log/nginx/access.log \
  && ln -sf /dev/stderr /var/log/nginx/error.log


# ***** CLEANUP *****
EXPOSE 80 443 1935

ADD entry.sh /

ENTRYPOINT ["/entry.sh"]

