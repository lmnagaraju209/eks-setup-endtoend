# Phase 2 Local Testing Guide

Quick guide to test Phase 2 services locally using Docker Compose.

## Prerequisites

- Docker Desktop installed and running
- Ports 3000 and 8082 available

## Start Services

```bash
cd services
docker-compose up
```

Or run in detached mode:
```bash
docker-compose up -d
```

## Verify Services Are Running

```bash
docker-compose ps
```

You should see both services with status "Up" and "healthy".

## Test Endpoints

### 1. Backend Health Check
```bash
curl http://localhost:8082/health
```

Expected response:
```json
{"status":"healthy","service":"backend"}
```

### 2. Frontend Health Check
```bash
curl http://localhost:3000/health
```

Expected response:
```json
{"status":"healthy","service":"frontend"}
```

### 3. List Items (via Frontend Proxy)
```bash
curl http://localhost:3000/api/v1/items
```

Expected response:
```json
[]
```

### 4. Create Item
```bash
curl -X POST http://localhost:3000/api/v1/items \
  -H "Content-Type: application/json" \
  -d '{"name":"Test Item","description":"Testing Phase 2"}'
```

Expected response:
```json
{"id":"<uuid>","name":"Test Item","description":"Testing Phase 2"}
```

### 5. Get Item by ID
```bash
curl http://localhost:3000/api/v1/items/<item-id>
```

### 6. Update Item
```bash
curl -X PUT http://localhost:3000/api/v1/items/<item-id> \
  -H "Content-Type: application/json" \
  -d '{"name":"Updated Item","description":"Updated description"}'
```

### 7. Delete Item
```bash
curl -X DELETE http://localhost:3000/api/v1/items/<item-id>
```

## Test via Browser

1. Open browser: http://localhost:3000
2. You should see the Item Manager UI
3. Try creating, listing, and deleting items

## Check Logs

```bash
# All services
docker-compose logs

# Backend only
docker-compose logs backend

# Frontend only
docker-compose logs frontend

# Follow logs
docker-compose logs -f
```

## Restart Services

```bash
docker-compose restart
```

## Rebuild After Code Changes

```bash
docker-compose down
docker-compose build --no-cache
docker-compose up
```

## Stop Services

```bash
docker-compose down
```

## Troubleshooting

### Port Already in Use
If port 8082 or 3000 is in use:
1. Change port in `docker-compose.yml`
2. Or stop the service using the port

### Services Not Starting
1. Check Docker Desktop is running
2. Check logs: `docker-compose logs`
3. Verify Docker has enough resources (CPU/Memory)

### Backend Not Responding
1. Check backend logs: `docker-compose logs backend`
2. Verify backend is healthy: `curl http://localhost:8082/health`
3. Check if port 8082 is accessible

### Frontend Can't Connect to Backend
1. Verify backend is running: `docker-compose ps`
2. Check frontend logs: `docker-compose logs frontend`
3. Verify BACKEND_URL in docker-compose.yml

## Success Criteria

✅ Both services show as "healthy" in `docker-compose ps`
✅ Backend `/health` returns 200 OK
✅ Frontend `/health` returns 200 OK
✅ Can create items via API
✅ Can list items via API
✅ Can delete items via API
✅ UI loads in browser
✅ Can interact with UI

## Next Steps

Once local testing passes:
1. Build Docker images for ECR
2. Push images to ECR
3. Deploy to EKS
4. See DEPLOYMENT_GUIDE.md for details

