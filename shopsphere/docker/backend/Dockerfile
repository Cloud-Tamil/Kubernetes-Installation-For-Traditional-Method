# ---------- Build ----------
FROM node:20-alpine AS builder
WORKDIR /app
COPY app/backend/package*.json ./
RUN npm install --omit=dev

# ---------- Runtime ----------
FROM node:20-alpine
RUN addgroup -S app && adduser -S app -G app
WORKDIR /app
COPY --from=builder --chown=app:app /app/node_modules ./node_modules
COPY --chown=app:app app/backend/ ./
USER app
EXPOSE 8080
CMD ["node", "server.js"]
