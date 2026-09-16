# ---------- Build stage ----------
FROM node:20-alpine AS builder

WORKDIR /app

# Copy frontend package files
COPY app/frontend/package*.json ./

# CHANGED: Using 'npm install' so it doesn't crash without a lockfile.
# REMOVED '--omit=dev' because frontends need devDependencies (like Vite, Webpack, etc.) to run the build step.
RUN npm install

# Copy the rest of the frontend source files
COPY app/frontend/ ./

# Run the build step to generate static assets
RUN npm run build

# OPTIMIZATION: Remove development dependencies to keep the image lightweight
RUN npm prune --production

# ---------- Runtime stage ----------
FROM node:20-alpine

# Create non-root user
RUN addgroup -S app && adduser -S app -G app

WORKDIR /app

# Copy built application from builder stage
COPY --from=builder --chown=app:app /app ./

USER app

EXPOSE 8080

CMD ["node", "server.js"]
