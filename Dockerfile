# latest stable is 18
FROM node:15
WORKDIR /src/rg-ops
COPY package*.json app.js ./
RUN npm install
EXPOSE 3000
CMD ["node", "app.js"]