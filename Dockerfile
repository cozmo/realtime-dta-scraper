FROM node:5.5.0
ADD . .
RUN npm install --production
CMD ["node_modules/coffee-script/bin/coffee", "scraper.coffee"]
