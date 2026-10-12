# syntax=docker/dockerfile:1

FROM node:22-alpine AS base
WORKDIR /app
ENV NEXT_TELEMETRY_DISABLED=1

FROM base AS dependencies
COPY package.json package-lock.json ./
# npm lockfiles generated on Windows can omit Lightning CSS's Linux optional
# package. Install the native binary explicitly for the Docker architecture.
RUN npm ci --include=optional \
    && case "$(uname -m)" in \
        aarch64) npm install --no-save --package-lock=false lightningcss-linux-arm64-musl@1.32.0 ;; \
        x86_64) npm install --no-save --package-lock=false lightningcss-linux-x64-musl@1.32.0 ;; \
        *) echo "Unsupported Alpine architecture: $(uname -m)" && exit 1 ;; \
    esac

FROM base AS builder
COPY --from=dependencies /app/node_modules ./node_modules
COPY . .
RUN npm run build

FROM node:22-alpine AS runner
WORKDIR /app
ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1
RUN addgroup --system --gid 1001 nodejs \
    && adduser --system --uid 1001 nextjs
COPY --from=builder --chown=nextjs:nodejs /app/public ./public
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static
COPY --from=builder --chown=nextjs:nodejs /app/scripts/create-admin.mjs ./scripts/create-admin.mjs
USER nextjs
EXPOSE 3000
ENV PORT=3000
ENV HOSTNAME=0.0.0.0
CMD ["node", "server.js"]
