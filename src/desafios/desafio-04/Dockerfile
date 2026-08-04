# ── Stage 1: builder ──────────────────────────────────────
FROM node:18-alpine AS builder

WORKDIR /build

COPY src/package.json ./
# npm install --omit=dev; cria node_modules mesmo sem dependências
RUN npm install --omit=dev

# ── Stage 2: runtime ──────────────────────────────────────
FROM node:18-alpine AS runtime

WORKDIR /app

# Criar pastas necessárias
RUN mkdir -p /app/cache /app/logs

# Usar usuário não-root (uid 1000 = node)
USER node

# Copiar package.json e código
COPY --chown=node:node src/ ./

EXPOSE 3000

HEALTHCHECK --interval=15s --timeout=5s --start-period=10s --retries=3 \
  CMD wget -qO- http://localhost:3000/health || exit 1

CMD ["node", "app.js"]
