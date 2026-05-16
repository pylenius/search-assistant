# Multi-stage build for the Vue SPA: Node build, nginx serve.
# Build context is apps/web/ — see docker-publish.sh.
#
# VITE_API_BASE is baked into the bundle at build time, so it MUST be passed
# as a --build-arg when invoking `docker build`.

FROM node:22-alpine AS build
WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci

COPY . .

ARG VITE_API_BASE
ARG VITE_HUB_PATH=/hub/search
ENV VITE_API_BASE=$VITE_API_BASE \
    VITE_HUB_PATH=$VITE_HUB_PATH
RUN npm run build

FROM nginx:alpine
COPY --from=build /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
