FROM node:20-alpine AS builder

WORKDIR /app

COPY app/frontend/package*.json ./
RUN npm ci --omit=dev

COPY app/frontend/ ./
RUN npm run build

FROM node:20-alpine

RUN addgroup -S app && adduser -S app -G app

WORKDIR /app

COPY --from=builder --chown=app:app /app ./

USER app

EXPOSE 8080

CMD ["node", "server.js"]
