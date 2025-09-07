# Doorlock Development Environment

This directory contains scripts and configurations for setting up a development environment for the Doorlock app.

## Quick Start

### Option 1: Using Make (Recommended)

```bash
# See all available commands
make help

# Setup and start development environment
make dev-setup        # Start PocketBase backend
make dev-start        # Start frontend (auto-install Flutter if needed, fallback to Docker)
make dev-start-docker  # Start frontend using Docker only (for network issues)
make install-flutter  # Install Flutter SDK manually
make test-setup       # Verify everything is working
```

### Option 2: Using Scripts Directly

1. **Install Flutter SDK (Automatic or Manual)**
   
   The development scripts will automatically install Flutter if it's not available. To install manually:
   
   ```bash
   # Use the provided installation script (recommended)
   ./scripts/install-flutter.sh
   ```
   
   Or install manually:
   a. Download Flutter SDK:
   - Visit: https://docs.flutter.dev/get-started/install/linux
   
   b. Extract and install:
   ```bash
   tar xf flutter_linux_*-stable.tar.xz
   sudo mv flutter /opt/flutter
   export PATH="/opt/flutter/bin:$PATH"
   ```
   
   c. Verify installation:
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
- `./scripts/start-frontend-docker.sh` - Start Flutter frontend using Docker only
- `./scripts/install-flutter.sh` - Install Flutter SDK locally
- `./scripts/restart-backend.sh` - Restart backend after changes

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

**Network/Download Issues:**
If you encounter 403 errors or download failures when installing Flutter:
- This is usually a temporary issue with Flutter's servers
- Try again in a few minutes
- Use the Docker fallback: `make dev-start-docker` or `./scripts/start-frontend-docker.sh`
- Or manually install Flutter using snap: `sudo snap install flutter --classic`

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