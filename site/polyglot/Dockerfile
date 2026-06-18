# Polyglot PureScript Website (current site)
# Static site served via nginx. Build context is site/polyglot; the built
# content lives in public/ (produced by build.sh, what static-httpd serves).
#
# Build:   docker build -t polyglot-website .
# Run:     docker run -p 3040:80 polyglot-website

FROM nginx:alpine

# Copy the built static site to nginx root (served at / via the edge layer)
COPY public/ /usr/share/nginx/html/

# Fix permissions
RUN chmod -R 755 /usr/share/nginx/html/ && \
    find /usr/share/nginx/html/ -type f -exec chmod 644 {} \;

# Listen on both IPv4 and IPv6 so an in-container `localhost` healthcheck
# (which may resolve to ::1) can connect. The site uses hash routing, so the
# SPA fallback is harmless but keeps deep links working if that ever changes.
RUN echo 'server { \
    listen 80; \
    listen [::]:80; \
    root /usr/share/nginx/html; \
    index index.html; \
    location / { \
        try_files $uri $uri/ /index.html; \
    } \
}' > /etc/nginx/conf.d/default.conf

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=3s \
  CMD wget -q --spider http://127.0.0.1/ || exit 1
