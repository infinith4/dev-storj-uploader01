# Build stage
FROM node:22-alpine as build

WORKDIR /app

# Copy package files and install dependencies
COPY package.json ./

# Create package-lock.json if it doesn't exist and install dependencies
RUN npm install --package-lock-only || true
RUN npm install

# Copy source code
COPY . .

# Build the application
RUN npm run build

# Production stage
FROM nginx:alpine

# Copy custom nginx config template
COPY nginx.conf.template /etc/nginx/conf.d/default.conf.template

# Copy built application
COPY --from=build /app/build /usr/share/nginx/html

# Copy entrypoint script
COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

# Expose port 9010
EXPOSE 9010

# Set environment variable with default value
ENV BACKEND_URL=http://localhost:8010

# Start nginx with entrypoint
ENTRYPOINT ["/docker-entrypoint.sh"]