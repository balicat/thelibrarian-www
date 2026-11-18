FROM nginx:alpine
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY index.html favicon.svg og.png robots.txt /usr/share/nginx/html/
