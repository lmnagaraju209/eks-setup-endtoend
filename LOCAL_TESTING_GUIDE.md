# Local Testing Guide with Docker Compose

This guide shows you how to run and test the TaskManager application locally using Docker Compose.

## Prerequisites

- **Docker Desktop** installed and running
- Ports available: `3000`, `5432`, `8082`

## Quick Start

1. **Navigate to services directory**:
   ```bash
   cd services
   ```

2. **Start all services**:
   ```bash
   docker-compose up
   ```

   Or run in detached mode (background):
   ```bash
   docker-compose up -d
   ```

3. **Access the application**:
   - Frontend: http://localhost:3000
   - Backend API: http://localhost:8082
   - Database: localhost:5432

## Services Included

The docker-compose file includes:

1. **PostgreSQL Database** (`postgres`)
   - Database: `itemsdb`
   - User: `postgres`
   - Password: `postgres`
   - Port: `5432`

2. **Backend Service** (`backend`)
   - Spring Boot REST API
   - Port: `8082` (mapped from container port 8080)
   - Automatically connects to PostgreSQL

3. **Frontend Service** (`frontend`)
   - Node.js/Express server
   - Port: `3000`
   - Proxies API calls to backend

## Health Checks

### Backend Health Check
```bash
curl http://localhost:8082/health
```

Expected response:
```json
{"status":"healthy","service":"backend"}
```

### Backend Readiness Check
```bash
curl http://localhost:8082/ready
```

Expected response:
```json
{"status":"ready","service":"backend"}
```

### Frontend Health Check
```bash
curl http://localhost:3000/health
```

Expected response:
```json
{"status":"healthy","service":"frontend"}
```

## Testing API Endpoints

### List All Items
```bash
curl http://localhost:3000/api/v1/items
```

### Create a New Item
```bash
curl -X POST http://localhost:3000/api/v1/items \
  -H "Content-Type: application/json" \
  -d '{"name":"My Task","description":"This is a test task"}'
```

### Get Item by ID
```bash
curl http://localhost:3000/api/v1/items/1
```

### Update an Item
```bash
curl -X PUT http://localhost:3000/api/v1/items/1 \
  -H "Content-Type: application/json" \
  -d '{"name":"Updated Task","description":"Updated description"}'
```

### Delete an Item
```bash
curl -X DELETE http://localhost:3000/api/v1/items/1
```

## View Logs

### All services:
```bash
docker-compose logs -f
```

### Specific service:
```bash
docker-compose logs -f backend
docker-compose logs -f frontend
docker-compose logs -f postgres
```

## Stop Services

```bash
docker-compose down
```

To also remove volumes (clears database data):
```bash
docker-compose down -v
```

## Rebuild Services

If you make code changes:

```bash
docker-compose down
docker-compose build --no-cache
docker-compose up
```

Or rebuild specific service:
```bash
docker-compose build backend
docker-compose up -d backend
```

## Troubleshooting

### Port Already in Use

If port 8082, 3000, or 5432 is already in use:

1. **Change ports in docker-compose.yml**:
   ```yaml
   ports:
     - "8083:8080"  # Change 8082 to 8083
   ```

2. **Or stop the conflicting service**:
   ```bash
   # Find what's using the port (Windows)
   netstat -ano | findstr :8082
   
   # Kill the process
   taskkill /PID <PID> /F
   ```

### Database Connection Issues

If backend can't connect to database:

1. **Check PostgreSQL is running**:
   ```bash
   docker-compose ps postgres
   ```

2. **Check PostgreSQL logs**:
   ```bash
   docker-compose logs postgres
   ```

3. **Verify environment variables**:
   ```bash
   docker-compose exec backend env | grep DB_
   ```

### Services Not Starting

1. **Check all services status**:
   ```bash
   docker-compose ps
   ```

2. **View detailed logs**:
   ```bash
   docker-compose logs
   ```

3. **Restart services**:
   ```bash
   docker-compose restart
   ```

### Clean Start (Remove Everything)

If you want to start completely fresh:

```bash
# Stop and remove containers, networks, volumes
docker-compose down -v

# Remove images (optional)
docker-compose down --rmi all

# Start fresh
docker-compose up --build
```

## Database Access

### Connect to PostgreSQL from Host Machine

```bash
# Using psql (if installed)
psql -h localhost -U postgres -d itemsdb

# Password: postgres
```

### Connect via Docker

```bash
docker-compose exec postgres psql -U postgres -d itemsdb
```

### View Database Tables

```sql
-- List all tables
\dt

-- View items table
SELECT * FROM item;
```

## Development Workflow

1. **Make code changes** in `services/backend` or `services/frontend`

2. **Rebuild the affected service**:
   ```bash
   docker-compose build backend
   docker-compose up -d backend
   ```

3. **Or restart all services**:
   ```bash
   docker-compose restart
   ```

## Next Steps

Once local testing works:

1. **Push code to GitHub** → Triggers GitHub Actions
2. **GitHub Actions builds and pushes** to ECR (`taskmanager-backend`, `taskmanager-frontend`)
3. **ArgoCD syncs** and deploys to EKS cluster
4. **Application runs** on Kubernetes with the same docker-compose services (now as Kubernetes pods)

## Summary

✅ **Docker Compose includes**: PostgreSQL + Backend + Frontend  
✅ **All services connected** and working together  
✅ **Health checks** verify everything is running  
✅ **API endpoints** ready to test  
✅ **Database persists** data in Docker volume  

**Ready to test!** Run `docker-compose up` and start testing. 🚀

