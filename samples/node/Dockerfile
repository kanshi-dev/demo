FROM node:24-alpine
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --omit=dev
COPY app.mjs ./
EXPOSE 8082
CMD ["node", "app.mjs"]
