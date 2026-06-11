# docker/worker/Dockerfile

FROM node:24-alpine
WORKDIR /app
COPY package.json ./
RUN npm install --omit=dev
COPY worker.js ./
USER node
CMD ["node", "worker.js"]
