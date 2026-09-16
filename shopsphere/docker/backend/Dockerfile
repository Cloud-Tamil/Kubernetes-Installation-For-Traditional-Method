# ---------- Build stage ----------
FROM node:20-alpine AS builder

WORKDIR /app

COPY app/backend/package*.json ./
RUN npm ci --omit=dev

COPY app/backend/ ./

# ---------- Runtime stage ----------
FROM node:20-alpine

# Create non-root user
RUN addgroup -S app && adduser -S app -G app

WORKDIR /app

COPY --from=builder --chown=app:app /app ./

USER app

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD wget -qO- http://localhost:8080/health/live || exit 1

CMD ["node", "server.js"]
