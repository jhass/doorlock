# Doorlock Development Environment

This directory contains scripts and configurations for setting up a development environment for the Doorlock app.

## Quick Start

### Option 1: Using Make (Recommended)

```bash
# See all available commands
make help

# Setup and start development environment
make dev-setup      # Start PocketBase backend
make test-setup     # Verify everything is working
make dev-start      # Start frontend development
```

### Option 2: Using Scripts Directly

1. **Install Flutter SDK**
   
   The development environment supports automatic Flutter installation when using GitHub Copilot agents (configured in `.github/workflows/copilot-setup-steps.yml`). For manual setup, follow these steps:
   
   a. Download Flutter SDK:
   - Visit: https://docs.flutter.dev/get-started/install/linux
   - Or use this direct link: https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.27.1-stable.tar.xz
   
   b. Extract and install:
   ```bash
   tar xf flutter_linux_*-stable.tar.xz
   sudo mv flutter /opt/flutter
   ```
   
   c. Add to your PATH:
   ```bash
   export PATH="/opt/flutter/bin:$PATH"
   ```
   
   d. Verify installation:
   ```bash
   flutter doctor
   ```

2. **Start PocketBase Backend**
   ```bash
   ./scripts/setup-dev.sh
   ```

3. **Start Frontend Development**
   ```bash
   cd app
   flutter pub get
   flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8090
   ```

### Option 3: Docker-based Setup (Alternative)

If you prefer not to install Flutter locally, you can use the Docker-based setup. The development scripts will automatically use Docker if Flutter is not available locally.

1. **Initial Setup**
   ```bash
   ./scripts/setup-dev.sh
   ```

2. **Start Frontend Development**
   ```bash
   ./scripts/start-frontend.sh
   ```

## Initial Configuration

After starting the services:

1. **Access PocketBase Admin UI**
   - Go to http://localhost:8080/_/
   - Create an admin account
   - Create a `doorlock_users` record for authentication

2. **Access the App**
   - Frontend: http://localhost:8090
   - Use the `doorlock_users` credentials to sign in

## Development Workflow

### Working on Frontend
- The Flutter development server runs at http://localhost:8090
- Changes to files in `app/` directory will trigger hot reload
- Frontend connects to PocketBase at http://localhost:8080

### Working on Backend
- Edit files in `pb_hooks/` or `pb_migrations/`
- Restart the backend to pick up changes:
  ```bash
  ./scripts/restart-backend.sh
  ```
- Your frontend will automatically reconnect

### Environment Configuration
The frontend uses configuration from `app/web/env.js`:
```javascript
window.env = {
  POCKETBASE_URL: "http://localhost:8080"
};
```

For development, this points to the local PocketBase instance.

## Architecture

```mermaid
    subgraph "Development Environment"
        frontend["Flutter Dev Server\n(Hot Reload)\nhttp://localhost:8090"] --> backend
        backend["PocketBase\n(Development Mode)\nhttp://localhost:8080"] --> hassio
        hassio[HomeAssistant REST API]
    end
```

## Available Scripts

- `./scripts/setup-dev.sh` - Start PocketBase backend
- `./scripts/start-frontend.sh` - Start Flutter frontend (tries local first, then Docker)
- `./scripts/restart-backend.sh` - Restart backend after changes

## Testing

Run the integration test suite with `make integration-test`. For CI environments, use `make ci-test`.

## Debugging

### PocketBase Issues
- View logs: `docker compose -f docker-compose.dev.yml logs -f pocketbase`
- Check if port 8080 is already in use
- Restart: `docker compose -f docker-compose.dev.yml restart pocketbase`

### Flutter Issues
- Ensure dependencies are installed: `cd app && flutter pub get`
- Check if port 8090 is already in use
- Run Flutter doctor: `flutter doctor`
- For web development issues: `flutter clean && flutter pub get`

### Network Issues
- The containers communicate via Docker's internal network
- Frontend in browser connects to localhost:8080 (PocketBase)
- If running on a different machine, update `POCKETBASE_URL` in `app/web/env.js`

## Cleanup

Stop all services:
```bash
docker compose -f docker-compose.dev.yml down
```

Remove volumes (⚠️ this will delete your development database):
```bash
docker compose -f docker-compose.dev.yml down -v
```