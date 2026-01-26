# Healthcare API Deployment

## Overview

FastAPI-based healthcare appointment management system deployed to Kubernetes.

**Image:** `ibraheemcisse/healthcare-api:latest`  
**Replicas:** 2  
**Resources:** 256Mi RAM, 100m CPU (request) / 512Mi RAM, 500m CPU (limit)

## Deployment
```bash
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
```

## Access
```bash
# Port-forward to test
kubectl port-forward svc/healthcare-api 8000:80

# Test endpoints
curl http://localhost:8000/health
curl http://localhost:8000/
```

## Endpoints

- `GET /` - API info
- `GET /health` - Health check
- `POST /patients` - Create patient
- `GET /patients` - List patients
- `GET /patients/{id}` - Get patient by ID
- `POST /appointments` - Schedule appointment
- `GET /doctors/{id}/schedule` - Doctor's schedule
