FROM node:20-alpine
WORKDIR /app
COPY package.json package-lock.json* ./
RUN npm ci --production --silent || npm i --production --silent
COPY . .
RUN npm run build
EXPOSE 3000
CMD ["node", "dist/index.js"]
