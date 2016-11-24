# Running this NGINX build

The following example is what I use to serve my [blog](https://enginepit.com/).

```
 docker run --net host\
     -v /usr/local/nginx:/etc/nginx\
     -v /data/log/nginx:/etc/nginx/logs\
     -v /data/log/nginx:/var/log/nginx\
     -v /data/configuration/nginx:/etc/nginx/conf\
     -v /data/tmp/nginx:/etc/nginx/tmp\
     -v /data/configuration/keys:/data/configuration/keys\
     -v /data/www:/data/www\
     -e EUID=$(id -u www-data)\
     -e EGID=$(id -g www-data)\
     -d --name nginx yuxhuang/alpine-libressl-luajit-nginx:mainline
```
