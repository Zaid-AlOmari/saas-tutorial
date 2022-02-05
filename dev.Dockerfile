FROM node:16-alpine3.14 AS base

RUN apk --update add curl
RUN apk --no-cache add --virtual builds-deps build-base 
RUN apk --update add git
RUN apk add --no-cache make gcc g++ python3

RUN npm install -g npm

RUN mkdir /app
WORKDIR /app

COPY ["./package.json", "debug.sh", "./"]

EXPOSE  3000
EXPOSE 5858

CMD ["sh", "debug.sh"]
