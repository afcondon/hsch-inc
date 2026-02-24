# Polyglot PureScript Website
# Static Halogen SPA served via nginx
#
# Build:   docker build -t psd3-website .
# Run:     docker run -p 3040:80 psd3-website

FROM nginx:alpine

# Copy static files to root (served at / via edge layer)
COPY public/ /usr/share/nginx/html/

# Fix permissions
RUN chmod -R 755 /usr/share/nginx/html/ && \
    find /usr/share/nginx/html/ -type f -exec chmod 644 {} \;

# SPA routing config at root
RUN echo 'server { \
    listen 80; \
    root /usr/share/nginx/html; \
    index index.html; \
    location / { \
        try_files $uri $uri/ /index.html; \
    } \
}' > /etc/nginx/conf.d/default.conf

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=3s \
  CMD wget -q --spider http://localhost/ || exit 1
