# Dockerfile for building and running the Flutter web app with runtime POCKETBASE_URL

# Build stage
FROM --platform=linux/amd64 ghcr.io/cirruslabs/flutter:stable AS build
WORKDIR /app
COPY . .
RUN flutter pub get && flutter build web --release

# Runtime stage
FROM nginx:alpine
WORKDIR /usr/share/nginx/html
COPY --from=build /app/build/web/ .

# Add entrypoint script to inject POCKETBASE_URL at runtime
COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh
ENTRYPOINT ["/docker-entrypoint.sh"]

# Expose port 80
EXPOSE 80

# Start nginx
CMD ["nginx", "-g", "daemon off;"]
