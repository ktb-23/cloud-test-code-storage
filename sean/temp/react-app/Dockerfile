FROM node:20.16.0-slim

WORKDIR /app

COPY package*.json ./

RUN npm ci

CMD ["npx", "vite", "--host"]