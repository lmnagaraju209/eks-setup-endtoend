# How to View Saved Data in TaskManager

There are several ways to view the data saved in your TaskManager application:

## Method 1: Using the API Endpoint (Easiest)

### Via Frontend Proxy (Recommended)
```bash
curl http://localhost:3000/api/v1/items
```

### Direct Backend Access
```bash
curl http://localhost:8082/api/v1/items
```

**Response format:**
```json
[
  {
    "id": 1,
    "name": "Test Task",
    "description": "Testing docker-compose setup"
  }
]
```

### Get Specific Item by ID
```bash
curl http://localhost:3000/api/v1/items/1
```

### Pretty Print JSON (PowerShell)
```powershell
curl http://localhost:3000/api/v1/items | ConvertFrom-Json | ConvertTo-Json
```

---

## Method 2: Direct Database Access via PostgreSQL

### Connect to Database Container
```bash
docker compose exec postgres psql -U postgres -d itemsdb
```

### View All Items
Once connected, run:
```sql
SELECT * FROM items;
```

### View with Formatting
```sql
SELECT id, name, description FROM items ORDER BY id;
```

### Count Items
```sql
SELECT COUNT(*) FROM items;
```

### Exit PostgreSQL
```sql
\q
```

---

## Method 3: One-Line Database Query

You can also query directly without entering the interactive shell:

```bash
# View all items
docker compose exec postgres psql -U postgres -d itemsdb -c "SELECT * FROM items;"

# View with formatted output
docker compose exec postgres psql -U postgres -d itemsdb -c "SELECT id, name, description FROM items ORDER BY id;"

# Count items
docker compose exec postgres psql -U postgres -d itemsdb -c "SELECT COUNT(*) as total_items FROM items;"
```

---

## Method 4: Using Browser

Open in your browser:
- **Frontend**: http://localhost:3000
- **Backend API**: http://localhost:8082/api/v1/items

---

## Method 5: View Database Tables and Schema

### List All Tables
```bash
docker compose exec postgres psql -U postgres -d itemsdb -c "\dt"
```

### View Table Schema
```bash
docker compose exec postgres psql -U postgres -d itemsdb -c "\d items"
```

### View All Table Data with Headers
```bash
docker compose exec postgres psql -U postgres -d itemsdb -c "SELECT * FROM items;" -A -F " | "
```

---

## Method 6: PowerShell Script for Better Formatting

Create a file `view-items.ps1`:

```powershell
$items = Invoke-RestMethod -Uri "http://localhost:3000/api/v1/items"
$items | Format-Table -AutoSize
```

Run it:
```powershell
.\view-items.ps1
```

---

## Quick Reference

| Method | Command | Best For |
|--------|---------|----------|
| **API (Frontend)** | `curl http://localhost:3000/api/v1/items` | Quick viewing |
| **API (Backend)** | `curl http://localhost:8082/api/v1/items` | Direct backend access |
| **Database** | `docker compose exec postgres psql -U postgres -d itemsdb -c "SELECT * FROM item;"` | Detailed database queries |
| **Browser** | http://localhost:3000/api/v1/items | Visual inspection |

---

## Example: Complete Workflow

1. **Create an item**:
   ```bash
   curl -X POST http://localhost:3000/api/v1/items -H "Content-Type: application/json" -d '{"name":"My Task","description":"Task description"}'
   ```

2. **View all items**:
   ```bash
   curl http://localhost:3000/api/v1/items
   ```

3. **View in database**:
   ```bash
   docker compose exec postgres psql -U postgres -d itemsdb -c "SELECT * FROM items;"
   ```

4. **Update item** (ID 1):
   ```bash
   curl -X PUT http://localhost:3000/api/v1/items/1 -H "Content-Type: application/json" -d '{"name":"Updated Task","description":"Updated description"}'
   ```

5. **View updated item**:
   ```bash
   curl http://localhost:3000/api/v1/items/1
   ```

6. **Delete item**:
   ```bash
   curl -X DELETE http://localhost:3000/api/v1/items/1
   ```

---

## Troubleshooting

### If API returns empty array `[]`
- Items may not have been created yet
- Try creating an item first with POST request

### If database connection fails
- Make sure PostgreSQL container is running: `docker compose ps`
- Check PostgreSQL logs: `docker compose logs postgres`

### If table doesn't exist
- Backend creates tables automatically on first startup
- Check backend logs: `docker compose logs backend`

