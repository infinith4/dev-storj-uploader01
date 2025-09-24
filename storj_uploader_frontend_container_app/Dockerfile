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

# Copy custom nginx config
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Copy built application
COPY --from=build /app/build /usr/share/nginx/html

# Expose port 9010
EXPOSE 9010

# Start nginx
CMD ["nginx", "-g", "daemon off;"]