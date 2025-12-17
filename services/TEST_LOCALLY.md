# Testing Services Locally

Guide for running and testing the application services on your local machine.

## Prerequisites

- Docker Desktop installed and running
- Ports 3000 and 8082 available
- **Java 17** (only required if you run the backend with Maven locally; Docker path does not require local Java)

## Quick Start

```bash
cd services
docker-compose up
```

## Running the backend with Maven (local Java 17)

If you prefer not to use Docker for the backend:

1) Install a **JDK 17** (example: Eclipse Temurin 17)
2) Set `JAVA_HOME` to your JDK 17 install directory and ensure `%JAVA_HOME%\\bin` is on `PATH`
3) Verify:

```bash
java -version
mvn -version
```

Then:

```bash
cd services/backend
mvn test
mvn spring-boot:run
```

This will:
- Build backend and frontend Docker images
- Start both services
- Backend available at http://localhost:8082
- Frontend available at http://localhost:3000

## Verify Services

### Backend Health Check
```bash
curl http://localhost:8082/health
```

Expected response:
```json
{"status":"healthy","service":"backend"}
```

### Frontend Health Check
```bash
curl http://localhost:3000/health
```

Expected response:
```json
{"status":"healthy","service":"frontend"}
```

### Test API Endpoints

List items:
```bash
curl http://localhost:3000/api/v1/items
```

Create item:
```bash
curl -X POST http://localhost:3000/api/v1/items \
  -H "Content-Type: application/json" \
  -d '{"name":"Test Item","description":"This is a test"}'
```

## Troubleshooting

### Port Already in Use
If port 8082 is in use, change it in `docker-compose.yml`:
```yaml
ports:
  - "8083:8080"  # Change 8082 to 8083
```

### Services Not Starting
Check logs:
```bash
docker-compose logs backend
docker-compose logs frontend
```

### Rebuild After Code Changes
```bash
docker-compose down
docker-compose build --no-cache
docker-compose up
```

## Development Workflow

1. Make code changes
2. Rebuild: `docker-compose build`
3. Restart: `docker-compose restart`
4. Check logs: `docker-compose logs -f`

## Stop Services

```bash
docker-compose down
```

To also remove volumes:
```bash
docker-compose down -v
```

