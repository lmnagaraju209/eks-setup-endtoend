# Services

Java backend and Node.js frontend for local development and testing.

## Local Prerequisites (recommended)

- **Java 17** (backend is Spring Boot 3.x)
- **Maven 3.9+**
- Docker Desktop (recommended for running both services together)

Verify:

```bash
java -version
mvn -version
```

## Run Locally

```bash
cd services
docker-compose up
```

- Frontend: http://localhost:3000
- Backend: http://localhost:8082

## Backend

Spring Boot REST API on port 8080 (mapped to 8082 externally).

Endpoints:
- `GET /health` - Health check
- `GET /ready` - Readiness check
- `GET /api/v1/items` - List items
- `POST /api/v1/items` - Create item
- `PUT /api/v1/items/{id}` - Update item
- `DELETE /api/v1/items/{id}` - Delete item

## Frontend

Express server on port 3000. Serves static UI and proxies API calls to backend.
