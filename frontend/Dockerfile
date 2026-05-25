FROM node:20-alpine AS build
WORKDIR /app
ARG VITE_CLIENT_NAME=Koiote
ENV VITE_CLIENT_NAME=$VITE_CLIENT_NAME
COPY package*.json ./
RUN npm install
COPY . .
RUN npm run build

FROM nginx:1.27-alpine
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/dist /usr/share/nginx/html
EXPOSE 80
