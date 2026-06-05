from fastapi import FastAPI
import os

app = FastAPI()

@app.get("/")
def read_root():
    return {
        "message": "Hello from ECS Fargate!",
        "version": os.getenv("APP_VERSION", "1.0.0"),
        "environment": os.getenv("ENVIRONMENT", "production")
    }

@app.get("/health")
def health_check():
    # Returns 200 OK for ALB target group health checks
    return {"status": "healthy"}
