FROM node:20-alpine AS deps

WORKDIR /opt/frontend

# Install only production dependencies for a smaller and safer runtime image.
COPY package*.json ./
RUN npm ci --omit=dev && npm cache clean --force

FROM node:20-alpine AS runtime

ENV NODE_ENV=production
WORKDIR /opt/frontend

COPY --from=deps /opt/frontend/node_modules ./node_modules
COPY package*.json ./
COPY server.js config.js ./
COPY api ./api
COPY helpers ./helpers
COPY public ./public

RUN chown -R node:node /opt/frontend
USER node

EXPOSE 8079

HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
	CMD node -e "require('http').get('http://127.0.0.1:8079/metrics', (r) => process.exit(r.statusCode === 200 ? 0 : 1)).on('error', () => process.exit(1))"

CMD ["node", "server.js"]


