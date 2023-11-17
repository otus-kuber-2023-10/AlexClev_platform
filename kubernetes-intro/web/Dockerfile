FROM nginx:1.24

RUN usermod -u 1001 nginx

WORKDIR /app
COPY nginx.conf /etc/nginx/nginx.conf
ADD /app ./
EXPOSE 8000
RUN touch /var/run/nginx.pid && chown 1001:101 /var/run/nginx.pid
RUN chown -R 1001:101 /var/cache/nginx

USER nginx

