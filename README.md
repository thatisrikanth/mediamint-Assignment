# Mediamint-Assignment

**Architectural Diagram**

The diagram below visualizes the complete solution, integrating the CI/CD workflow (orchestrated by GitHub Actions) with the modular infrastructure deployed on AWS using Terraform.

<img width="801" height="432" alt="image" src="https://github.com/user-attachments/assets/2db766f5-f427-40ad-8569-e350821c1c97" />


**Key Flow Areas:**

A: **CI/CD Pipeline**: The continuous workflow that transforms code updates into a stable deployment.

B: **AWS Infrastructure (Production VPC)**: The network security, compute (Fargate), and traffic routing layers.

C: **Monitoring & Recovery**: The automated feedback loop using CloudWatch and GitHub Actions to handle failures via rolling updates and potential rollbacks.


# AWS ECS Fargate Deployment Pipeline

## Project Goal
To build and operate a fully automated CI/CD pipeline that deploys a containerized Python FastAPI application to Amazon ECS Fargate, ensuring zero-downtime rolling updates and automated rollback capabilities based on health metrics.

---

## 1. Prerequisites Checklist

Before proceeding, ensure you have the following configured:

1.  **AWS Account**: An active AWS account with Administrator access.
2.  **AWS CLI**: Installed and configured locally (`aws configure`).
3.  **Terraform**: Installed locally (>= v1.6.0).
4.  **Docker**: Installed and running (required for initial image build).
5.  **GitHub Repository**: A repository for this project where you have `admin` permissions to set secrets.

---

## 2. Secrets Management

You must add the following **Repository Secrets** in GitHub (`Settings > Secrets and variables > Actions`):

| Secret Name | Description | Example |
| :--- | :--- | :--- |
| `AWS_ACCESS_KEY_ID` | IAM User Access Key | `xxxxxxxxxxxxxxxxx` |
| `AWS_SECRET_ACCESS_KEY` | IAM User Secret Key | `xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx` |

> *Note: Ensure the IAM user associated with these keys has permissions for ECR, ECS, EC2 (VPC), IAM, ALB, and CloudWatch.*

---

## 3. Runbook: Infrastructure Deployment

This section describes how to bootstrap the AWS environment using Terraform.

### 3.1 Initial Deployment (Bootstrap)

Because the ECS Task Definition requires an ECR image URI, we must deploy the infrastructure in two phases.

#### **Phase 1: Bootstrap Registry & Network**
1.  Navigate to the terraform directory: `cd terraform`
2.  Initialize Terraform: `terraform init`
3.  Deploy without the app image:
    ```bash
    terraform apply -var="container_image=" -auto-approve
    ```
    *This creates the VPC, ECR repository, IAM roles, ALB, and ECS cluster, but the ECS Service will initially fail to start because no image exists.*

#### **Phase 2: CI/CD Activation**
1.  Commit and push your application code (`app/`, `Dockerfile`, `.github/`) to the `main` branch.
2.  The GitHub Actions pipeline will automatically trigger. It will build the first Docker image, push it to ECR, and update the ECS Service with the real image URI.

### 3.2 Ongoing Infrastructure Updates
When you modify Terraform files (e.g., changing ALB rules or IAM policies):
1.  Run `terraform plan` to review changes.
2.  Run `terraform apply` to implement changes.

---

## 4. Runbook: Application Deployment & Rolling Updates

This project uses **ECS Rolling Updates** for application deployments.

### 4.1 Deployment Flow
1.  **Code Push**: A developer pushes clean code updates to the `main` branch.
2.  **Pipeline**: GitHub Actions triggers automatically.
3.  **Validation**: `flake8` lints the code and `pytest` runs unit tests.
4.  **Build & Push**: A new Docker image is built, tagged with the Git SHA, and pushed to ECR.
5.  **Rolling Update**: The pipeline updates the ECS Service task definition. ECS automatically handles the deployment:
    * It spins up *new* tasks running the new image.
    * The ALB performs health checks (`/health`).
    * Once healthy, traffic is directed to the *new* tasks.
    * *Old* tasks are gracefully drained and stopped.

### 4.2 Verifying Deployment Success
* **Via Web Browser**: Visit the ALB DNS name (provided in Terraform output) and confirm the `version` JSON key matches your update.
* **Via AWS Console**: Check `ECS > Clusters > [environment]-cluster > Services > Events`.

---

## 5. Runbook: Logs & Monitoring

### 5.1 Accessing Application Logs
Logs from the container are sent to CloudWatch Logs.
1.  Go to `CloudWatch > Log groups`.
2.  Select `/ecs/production-app`.
3.  View log streams from individual Fargate tasks.

### 5.2 Monitoring Alarms
We monitor application health using an ALB 5XX error count.
* **Alarm Name**: `production-high-5xx-errors`
* **Description**: Triggers if the application returns more than 3 5XX responses within a one-minute period.

---

## 6. Runbook: Rollback Strategy

The rollback strategy is designed to recover quickly from a failed or unstable deployment.

### 6.1 Strategy A: Automated Rollback (Post-Deployment Check)
The GitHub Actions pipeline includes a `Wait for Service Stability` step.
* **Trigger**: If ECS cannot stabilize the service (e.g., new tasks are crash-looping or failing ALB health checks) within the deployment timeout (default 10 mins).
* **Action**: The pipeline catches the failure, enters the `if: failure()` block, and automatically triggers an AWS CLI command to update the ECS service to the *previous* stable Task Definition revision.

### 6.2 Strategy B: Manual Rollback (Operator Activated)
If the deployment stabilizes but is functionally broken (e.g., serious bug not caught by tests), a human operator can activate a rollback.

**Using AWS CLI:**
Execute the following command, replacing `REVISION_NUMBER` with the known stable revision (e.g., `production-task:5`):
```bash
aws ecs update-service --cluster production-cluster --service production-service --task-definition production-task:REVISION_NUMBER
