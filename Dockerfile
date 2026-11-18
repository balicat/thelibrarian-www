FROM nginx:alpine
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY security_headers.conf /etc/nginx/security_headers.conf
COPY index.html og.png icon-224.png favicon-32.png favicon-64.png apple-touch-icon.png robots.txt /usr/share/nginx/html/
