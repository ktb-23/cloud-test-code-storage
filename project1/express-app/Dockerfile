# Dockerfile for Express
FROM node:14

# Set working directory
WORKDIR /app

# Install dependencies
COPY package*.json ./
RUN npm install

# Copy app files
COPY . .

# Expose port
EXPOSE 4000

# Start the app
CMD ["node", "index.js"]
