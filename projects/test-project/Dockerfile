FROM nginx:alpine

# Install required packages
RUN apk add --no-cache curl

# Create temp directories
RUN mkdir -p /tmp/client_temp \
    && mkdir -p /tmp/proxy_temp \
    && mkdir -p /tmp/fastcgi_temp \
    && mkdir -p /tmp/uwsgi_temp \
    && mkdir -p /tmp/scgi_temp \
    && chmod 777 /tmp/client_temp \
    && chmod 777 /tmp/proxy_temp \
    && chmod 777 /tmp/fastcgi_temp \
    && chmod 777 /tmp/uwsgi_temp \
    && chmod 777 /tmp/scgi_temp

# Copy configuration files
COPY nginx.conf /etc/nginx/nginx.conf
COPY conf.d/ /etc/nginx/conf.d/
COPY html/ /usr/share/nginx/html/

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:8080/ || exit 1

EXPOSE 8080

CMD ["nginx", "-g", "daemon off;"]
