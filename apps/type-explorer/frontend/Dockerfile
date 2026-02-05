# Type Explorer Frontend
# Static PureScript app served via nginx
#
# Build:   docker build -t type-explorer .
# Run:     docker run -p 8080:80 type-explorer

FROM nginx:alpine

# Copy static files to /types/ path (matches URL prefix)
COPY public/ /usr/share/nginx/html/types/

# Fix permissions
RUN chmod -R 755 /usr/share/nginx/html/ && \
    find /usr/share/nginx/html/ -type f -exec chmod 644 {} \;

# SPA routing config under /types/
RUN echo 'server { \
    listen 80; \
    root /usr/share/nginx/html; \
    index index.html; \
    location /types/ { \
        try_files $uri $uri/ /types/index.html; \
    } \
}' > /etc/nginx/conf.d/default.conf

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=3s \
  CMD wget -q --spider http://localhost/ || exit 1
