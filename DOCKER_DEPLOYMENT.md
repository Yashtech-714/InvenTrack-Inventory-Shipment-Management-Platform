# WMS System - Docker Deployment Guide

This guide provides instructions for building and deploying the WMS (Warehouse Management System) using Docker and Docker Compose.

## Prerequisites

- Docker (version 20.10 or higher)
- Docker Compose (version 2.0 or higher)
- Git (for cloning the repository)

### Installation

**Windows:**
1. Download and install [Docker Desktop](https://www.docker.com/products/docker-desktop)
2. Docker Compose is included with Docker Desktop

**macOS:**
1. Download and install [Docker Desktop](https://www.docker.com/products/docker-desktop)
2. Docker Compose is included with Docker Desktop

**Linux:**
```bash
# Install Docker
sudo apt-get update
sudo apt-get install docker.io

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/download/v2.20.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
```

## Quick Start

### 1. Build and Deploy with Docker Compose (Recommended)

Navigate to the project root directory and run:

```bash
docker-compose up --build
```

This command will:
- Build the backend Docker image
- Build the frontend Docker image
- Create a shared network
- Start both services
- Wait for services to become healthy before starting dependent services

**Output:**
- Backend API: http://localhost:8080
- Frontend Application: http://localhost:5173
- H2 Database Console: http://localhost:8080/h2-console

### 2. Stop the Services

```bash
docker-compose down
```

### 3. View Logs

```bash
# View all logs
docker-compose logs -f

# View specific service logs
docker-compose logs -f backend
docker-compose logs -f frontend
```

## Individual Docker Builds

### Build Backend Image

```bash
docker build -t wms-backend:latest ./backend
```

### Build Frontend Image

```bash
docker build -t wms-frontend:latest ./frontend
```

### Run Backend Container

```bash
docker run -p 8080:8080 \
  -e SERVER_PORT=8080 \
  --name wms-backend \
  wms-backend:latest
```

### Run Frontend Container

```bash
docker run -p 5173:5173 \
  -e VITE_API_BASE_URL=http://localhost:8080 \
  --name wms-frontend \
  --link wms-backend:backend \
  wms-frontend:latest
```

## Access Points

| Service | URL | Description |
|---------|-----|-------------|
| Frontend | http://localhost:5173 | React application |
| Backend API | http://localhost:8080 | Spring Boot API |
| H2 Console | http://localhost:8080/h2-console | Database management |

## Configuration

### Environment Variables

**Backend (.env or docker-compose.yml):**
- `SERVER_PORT`: Application port (default: 8080)
- `SPRING_DATASOURCE_URL`: Database connection URL
- `SPRING_JPA_HIBERNATE_DDL_AUTO`: JPA DDL strategy (update/create/validate)
- `JAVA_OPTS`: JVM options

**Frontend (.env or docker-compose.yml):**
- `VITE_API_BASE_URL`: Backend API base URL (default: http://localhost:8080)

## Dockerfile Structure

### Backend Dockerfile
- **Stage 1 (Builder):** Maven builds the Spring Boot JAR
- **Stage 2 (Runtime):** Lightweight Alpine JRE runs the application
- **Multi-stage build:** Reduces final image size by 70%+

### Frontend Dockerfile
- **Stage 1 (Builder):** Node builds the React application
- **Stage 2 (Runtime):** Lightweight Alpine Node serves the application
- **Using Serve:** Production-grade static file serving

## Health Checks

Both services include health checks:
- Backend: Checks H2 console endpoint every 30 seconds
- Frontend: Checks application endpoint every 30 seconds
- Auto-restart on failure (unless-stopped policy)

## Troubleshooting

### Port Already in Use

If ports 8080 or 5173 are already in use:

```bash
# Change ports in docker-compose.yml
ports:
  - "8081:8080"  # Backend on 8081
  - "5174:5173"  # Frontend on 5174
```

### Services Not Communicating

1. Verify network is created:
   ```bash
   docker network ls
   ```

2. Check container connectivity:
   ```bash
   docker network inspect wms-network
   ```

3. View service logs:
   ```bash
   docker-compose logs backend
   docker-compose logs frontend
   ```

### Database Issues

1. Check H2 Console: http://localhost:8080/h2-console
2. Verify database connection in logs:
   ```bash
   docker-compose logs backend | grep -i database
   ```

### Build Failures

1. Clean up and rebuild:
   ```bash
   docker-compose down -v
   docker system prune
   docker-compose up --build
   ```

2. Check build logs:
   ```bash
   docker-compose build --no-cache --verbose
   ```

## Production Deployment

For production environments:

1. **Use environment-specific configurations:**
   ```yaml
   # docker-compose.prod.yml
   services:
     backend:
       image: myregistry/wms-backend:v1.0
       environment:
         - SPRING_DATASOURCE_URL=jdbc:postgresql://db:5432/wmsdb
         - SPRING_JPA_HIBERNATE_DDL_AUTO=validate
   ```

2. **Use volume for persistent data:**
   ```yaml
   volumes:
     - wms-data:/app/data
   ```

3. **Implement proper logging:**
   - Use ELK stack or similar for log aggregation
   - Configure log rotation and retention

4. **Use container orchestration:**
   - Deploy to Kubernetes for scalability
   - Use AWS ECS/Fargate for managed services

## Performance Optimization

### Backend
- JVM heap size: Adjust `JAVA_OPTS` based on available memory
- Cache strategy: Configure Spring Cache with Redis
- Database: Consider PostgreSQL for production

### Frontend
- Enable gzip compression in reverse proxy
- Use CDN for static assets
- Implement service worker for offline support

## Security Considerations

1. **Network Security:**
   - Use internal networks for inter-service communication
   - Expose only necessary ports

2. **Environment Variables:**
   - Use `.env` files (not in git)
   - Implement secrets management for production

3. **Image Security:**
   - Use specific base image versions (not `latest`)
   - Scan images for vulnerabilities
   - Run containers as non-root users

## Additional Resources

- [Docker Documentation](https://docs.docker.com)
- [Docker Compose Reference](https://docs.docker.com/compose/compose-file)
- [Spring Boot Docker Guide](https://spring.io/guides/topicals/spring-boot-docker)
- [Best Practices for Node.js in Docker](https://nodejs.org/en/docs/guides/nodejs-docker-webapp)

## Support

For issues or questions:
1. Check the troubleshooting section
2. Review Docker logs
3. Verify Docker and Docker Compose versions
4. Consult project documentation
