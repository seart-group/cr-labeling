FROM node:18.14-alpine

WORKDIR /app

COPY ./views ./views
COPY ./public ./public
COPY ./index.js ./index.js
COPY ./package.json ./package.json
COPY ./.env.template ./.env.template

ARG DATABASE_NAME
ARG DATABASE_USER
ARG DATABASE_PASS
ARG DATABASE_PORT
ARG NODE_ENV=production

RUN apk update && apk add gettext
RUN envsubst < .env.template > .env
RUN npm install

CMD ["npm", "run", "start"]
