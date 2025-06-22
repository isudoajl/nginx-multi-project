FROM nginx:alpine

# Install required packages
RUN apk add --no-cache openssl

# Create nginx user
RUN adduser -D -H -u 1000 -s /sbin/nologin nginx

# Create required directories
RUN mkdir -p /etc/nginx/conf.d/domains \
    && mkdir -p /etc/nginx/certs \
    && mkdir -p /usr/share/nginx/html \
    && mkdir -p /var/log/nginx

# Generate DH parameters
RUN openssl dhparam -out /etc/nginx/dhparam.pem 2048

# Set permissions
RUN chown -R nginx:nginx /var/log/nginx \
    && chmod -R 755 /var/log/nginx

# Switch to non-root user
USER nginx

EXPOSE 80 443

CMD ["nginx", "-g", "daemon off;"] 