FROM nginx:alpine

# Install required packages
RUN apk add --no-cache curl

# Copy SSL certificates
COPY --chown=nginx:nginx certs/cert.pem /etc/ssl/certs/cert.pem
COPY --chown=nginx:nginx certs/cert-key.pem /etc/ssl/private/cert-key.pem

# Create required directories and set permissions
RUN mkdir -p /etc/nginx/conf.d \
    && mkdir -p /usr/share/nginx/html \
    && mkdir -p /var/log/nginx \
    && chown -R nginx:nginx /var/log/nginx \
    && chmod -R 755 /var/log/nginx

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost/ || exit 1

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
