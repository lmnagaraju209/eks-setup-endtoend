# Quick Start - Run TaskManager Locally

## Prerequisites Check ✅

- ✅ Docker installed (version 29.1.2)
- ✅ Docker Compose installed (version 2.40.3)
- ✅ Docker Compose configuration validated

## Steps to Run

### 1. Start Docker Desktop

**Important**: Docker Desktop must be running before starting services.

- Open Docker Desktop application
- Wait for it to fully start (whale icon in system tray should be steady)

### 2. Start All Services

```bash
cd services
docker-compose up
```

Or run in background (detached mode):
```bash
docker-compose up -d
```

### 3. Verify Services Are Running

```bash
# Check all services status
docker-compose ps

# View logs
docker-compose logs -f
```

### 4. Test the Application

Once services are up (takes ~30-60 seconds):

**Health Checks:**
```bash
# Backend health
curl http://localhost:8082/health

# Frontend health  
curl http://localhost:3000/health
```

**API Testing:**
```bash
# List items (should return empty array initially)
curl http://localhost:3000/api/v1/items

# Create a task
curl -X POST http://localhost:3000/api/v1/items ^
  -H "Content-Type: application/json" ^
  -d "{\"name\":\"My First Task\",\"description\":\"Test task\"}"

# List items again (should show your task)
curl http://localhost:3000/api/v1/items
```

**Browser Access:**
- Frontend UI: http://localhost:3000
- Backend API: http://localhost:8082

### 5. Stop Services

```bash
# Stop services
docker-compose down

# Stop and remove volumes (clears database)
docker-compose down -v
```

## What's Running

1. **PostgreSQL Database** (port 5432)
   - Database: `itemsdb`
   - User: `postgres`
   - Password: `postgres`

2. **Backend Service** (port 8082)
   - Spring Boot REST API
   - Connects to PostgreSQL automatically

3. **Frontend Service** (port 3000)
   - Node.js/Express server
   - Proxies API calls to backend

## Troubleshooting

### Docker Desktop Not Running
- Error: `failed to connect to the docker API`
- Solution: Start Docker Desktop application

### Port Already in Use
- Change ports in `docker-compose.yml` if 3000, 5432, or 8082 are taken

### Services Won't Start
- Check logs: `docker-compose logs`
- Rebuild: `docker-compose build --no-cache`
- Clean start: `docker-compose down -v && docker-compose up --build`

## Next Steps After Local Testing

Once local testing works:
1. ✅ Push code to GitHub
2. ✅ GitHub Actions builds and pushes to ECR
3. ✅ ArgoCD deploys to EKS
4. ✅ Application runs on Kubernetes

---

**Ready to test!** Just start Docker Desktop and run `docker-compose up` 🚀

