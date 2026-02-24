# PSD3 Dev Dashboard
# Node.js Express server for managing showcase servers
#
# Build:   docker build -t psd3-dashboard .
# Run:     docker run -p 9000:9000 psd3-dashboard

FROM node:20-alpine

WORKDIR /app

# Install dependencies
COPY package*.json ./
RUN npm ci --only=production

# Copy application files
COPY server.js config.json ./
COPY public/ ./public/

EXPOSE 9000

HEALTHCHECK --interval=30s --timeout=3s \
  CMD wget -q --spider http://localhost:9000/ || exit 1

CMD ["node", "server.js"]
