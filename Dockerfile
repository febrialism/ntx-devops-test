# ---- Stage 1: Build ----
# Use the official Node.js 22 Alpine image, which is lightweight and secure
FROM node:22-alpine AS builder

# Set the working directory inside the container
WORKDIR /usr/src/app

# Copy package files and install only production dependencies
COPY package*.json ./
RUN npm install --only=production

# Copy the rest of your application's source code
COPY . .

# ---- Stage 2: Production ----
# Start fresh from the same small base image
FROM node:22-alpine

WORKDIR /usr/src/app

# Copy the installed dependencies and source code from the 'builder' stage
COPY --from=builder /usr/src/app/node_modules ./node_modules
COPY --from=builder /usr/src/app ./

# Expose the port the app runs on
EXPOSE 3000

# Define the user to run the app (improves security)
USER node

# Command to run the application
RUN apk add --no-cache tini
ENTRYPOINT ["/sbin/tini", "--"]
CMD ["node", "app.js"]
