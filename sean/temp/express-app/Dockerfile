# 24.08.01 기준 node v20.16.0

FROM node:lts-alpine

WORKDIR /app

COPY . /app

RUN npm ci

CMD ["npm", "run", "start"]