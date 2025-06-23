FROM nginx:alpine

# Install required packages
RUN apk add --no-cache openssl

# Create required directories
RUN mkdir -p /etc/nginx/conf.d/domains \
    && mkdir -p /etc/nginx/certs \
    && mkdir -p /usr/share/nginx/html \
    && mkdir -p /var/log/nginx

# Generate DH parameters
RUN openssl dhparam -out /etc/nginx/dhparam.pem 2048

# Set permissions for log files
RUN touch /var/log/nginx/error.log /var/log/nginx/access.log \
    && chmod 644 /var/log/nginx/error.log /var/log/nginx/access.log

EXPOSE 80 443

CMD ["nginx", "-g", "daemon off;"] 