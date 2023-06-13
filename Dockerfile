# latest stable is 18
FROM node:15
WORKDIR /src/rg-ops
COPY --chown=node:node package*.json app.js ./
RUN npm ci --only=production
EXPOSE 3000
USER node
CMD ["node", "app.js"]