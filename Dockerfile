# =========================
# BUILD STAGE
# =========================
FROM node:20-alpine AS builder

RUN apk update && \
    apk add --no-cache git ffmpeg wget curl bash openssl dos2unix

LABEL version="2.3.1" description="API to control WhatsApp features through HTTP requests." 
LABEL maintainer="Davidson Gomes" git="https://github.com/DavidsonGomes"
LABEL contact="contato@evolution-api.com"

WORKDIR /evolution

# Instala dependências
COPY ./package*.json ./
COPY ./tsconfig.json ./
COPY ./tsup.config.ts ./
RUN npm ci --silent

# Copia os arquivos do projeto
COPY ./src ./src
COPY ./public ./public
COPY ./prisma ./prisma
COPY ./manager ./manager
COPY ./.env.example ./.env
COPY ./runWithProvider.cjs ./
COPY ./Docker ./Docker

# Corrige permissões de scripts
RUN chmod +x ./Docker/scripts/* && dos2unix ./Docker/scripts/*

# Prisma: gera os clientes
COPY ./prisma/schema.prisma ./schema.prisma
RUN npx prisma generate

# Compila o projeto
RUN npm run build

# =========================
# FINAL STAGE
# =========================
FROM node:20-alpine AS final

RUN apk update && \
    apk add --no-cache tzdata ffmpeg bash openssl

ENV TZ=America/Sao_Paulo
ENV DOCKER_ENV=true

WORKDIR /evolution

COPY --from=builder /evolution/package.json ./package.json
COPY --from=builder /evolution/package-lock.json ./package-lock.json
COPY --from=builder /evolution/node_modules ./node_modules
COPY --from=builder /evolution/dist ./dist
COPY --from=builder /evolution/prisma ./prisma
COPY --from=builder /evolution/manager ./manager
COPY --from=builder /evolution/public ./public
COPY --from=builder /evolution/.env ./.env
COPY --from=builder /evolution/Docker ./Docker
COPY --from=builder /evolution/runWithProvider.cjs ./runWithProvider.cjs

# Garante que o script de deploy está executável
RUN chmod +x ./Docker/scripts/deploy_database.sh && dos2unix ./Docker/scripts/deploy_database.sh

# Comando de entrada
ENTRYPOINT ["/bin/bash", "-c", ". ./Docker/scripts/deploy_database.sh && node runWithProvider.cjs && node dist/main" ]
