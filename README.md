# WMS System

Warehouse Management System for managing inventory, orders, purchase orders, storage locations, shipments, and user roles in a warehouse workflow.

This project is built with a Spring Boot backend and a React frontend, and includes role-based access for managers, staff, customers, and suppliers.

## Features

- Inventory tracking and stock management
- Product catalog and pricing
- Storage location and warehouse layout management
- Customer order processing
- Purchase order creation and supplier delivery workflows
- Shipment lifecycle tracking
- Role-based dashboards and access control
- Redis-based caching for application performance
- H2 in-memory database for quick local setup
- Docker-based deployment support

## Tech Stack

- Backend: Java 17, Spring Boot 3, Spring Data JPA, Redis, H2 Database
- Frontend: React, Vite, Axios
- Deployment: Docker Compose

## Project Structure

```text
wms-system/
├── backend/         # Spring Boot REST API
├── frontend/        # React application
├── docker-compose.yml
├── DOCKER_DEPLOYMENT.md
├── REDIS_CACHE_GUIDE.md
├── .gitignore
├── README.md
└── ...
```

## Demo Credentials

The application seeds demo users automatically.

| Role | Email | Password |
|------|-------|----------|
| Manager | manager@wms.com | manager123 |
| Staff | staff@wms.com | staff123 |
| Customer | customer@wms.com | customer123 |
| Supplier | supplier@wms.com | supplier123 |

## Running the Project

### Option 1: Manual Run

#### Backend

```bash
cd backend
mvn spring-boot:run
```

The backend runs on:

- http://localhost:8080
- H2 console: http://localhost:8080/h2-console

#### Frontend

```bash
cd frontend
npm install
npm run dev
```

The frontend runs on:

- http://localhost:5173

### Option 2: Docker Compose

```bash
docker compose up --build
```

This starts:

- Backend: http://localhost:8080
- Frontend: http://localhost:5173
- Redis: localhost:6379

## Notes

- The database is configured as an in-memory H2 database for local development.
- Redis is used for caching and can be run with Docker Compose or locally.
- Data is initialized automatically on application startup.

## License

This project is for academic/portfolio use and is not currently licensed for commercial distribution.

## Authors

This project was developed as an OOAD / warehouse management system project and includes role-based warehouse workflows for operations, inventory, orders, and suppliers.
