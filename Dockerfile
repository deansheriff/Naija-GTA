FROM node:22-bookworm-slim AS build
WORKDIR /build
COPY server/package.json server/package-lock.json ./
RUN npm ci --no-fund
COPY server/tsconfig*.json ./
COPY server/src ./src
RUN npm run build && npm prune --omit=dev

FROM node:22-bookworm-slim AS runtime
ENV NODE_ENV=production HOST=0.0.0.0 PORT=8787 STATIC_ROOT=/app/public
WORKDIR /app
COPY --from=build --chown=node:node /build/node_modules ./node_modules
COPY --from=build --chown=node:node /build/dist ./dist
COPY --chown=node:node server/package.json ./package.json
COPY --chown=node:node server/migrations ./migrations
COPY --chown=node:node web/dist ./public
RUN mkdir -p /app/data && chown node:node /app/data
USER node
EXPOSE 8787
HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
  CMD node -e "fetch('http://127.0.0.1:8787/api/health').then(r=>{if(!r.ok)process.exit(1)}).catch(()=>process.exit(1))"
CMD ["node", "dist/index.js"]
