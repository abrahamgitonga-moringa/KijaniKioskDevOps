FROM node:18-alpine

WORKDIR /app

# Copy only manifests first (for layer caching)
COPY package.json package-lock.json ./

# Install production dependencies
RUN npm ci --only=production

# Copy remaining files
COPY . .

# Expose app port
EXPOSE 3001

# Run directly via node (exec form)
CMD ["node", "dist/index.js"]
