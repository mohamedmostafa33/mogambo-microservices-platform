FROM node:20-alpine AS deps

WORKDIR /opt/frontend

# Install only production dependencies and keep this layer cacheable.
COPY package*.json ./
RUN npm ci --omit=dev && npm cache clean --force

FROM node:20-alpine AS build

ENV NODE_ENV=production
WORKDIR /opt/frontend

COPY --from=deps /opt/frontend/node_modules ./node_modules
COPY package*.json ./
COPY server.js config.js ./
COPY api ./api
COPY helpers ./helpers
COPY public ./public

FROM node:20-alpine AS runtime

ENV NODE_ENV=production
WORKDIR /opt/frontend

# Copy only the runtime payload and set ownership at copy time.
COPY --from=build --chown=node:node /opt/frontend ./

USER node

EXPOSE 8079

CMD ["node", "server.js"]


