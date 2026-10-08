# NimbusCart

> **Automated three-tier product catalog application deployed on AWS using Terraform, Docker, and a secure multi-VPC architecture.**

## Table of Contents

* [Overview](#overview)
* [Architecture](#architecture)
* [Key Features](#key-features)
* [Technology Stack](#technology-stack)
* [Project Structure](#project-structure)
* [Network Design](#network-design)
* [Application Tiers](#application-tiers)
* [API Reference](#api-reference)
* [Prerequisites](#prerequisites)
* [AWS Infrastructure](#aws-infrastructure)
* [Configuration](#configuration)
* [Deployment](#deployment)
* [Verification](#verification)
* [Terraform Outputs](#terraform-outputs)
* [Security](#security)
* [Architecture Considerations](#architecture-considerations)
* [Troubleshooting](#troubleshooting)
* [Cleanup](#cleanup)
* [Contributing](#contributing)
* [License](#license)

---

## Overview

NimbusCart is a lightweight full-stack product catalog application designed to demonstrate a production-oriented **three-tier architecture on AWS**.

The application separates the web, application, and database layers and deploys them across isolated network environments. Infrastructure is provisioned with **Terraform**, while the application API runs inside a **Docker container**.

The architecture uses two VPCs:

* `app-vpc` — hosts the public web tier and private application tier.
* `data-vpc` — hosts the isolated database tier.

The VPCs communicate through **AWS VPC Peering**, while the application tier reaches the public internet through a **NAT Gateway** without exposing the application server directly to the internet.

---

## Architecture

```text
                         Internet
                            │
                            │ HTTP :80
                            ▼
┌──────────────────────────────────────────────────────────────┐
│                    VPC-A: app-vpc                            │
│                      10.0.0.0/16                             │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐  │
│  │ Public Subnet: 10.0.1.0/24                            │  │
│  │                                                        │  │
│  │   Internet Gateway                                    │  │
│  │        │                                               │  │
│  │        ├── NAT Gateway + Elastic IP                    │  │
│  │        │                                               │  │
│  │        └── EC2 Web Tier                                │  │
│  │             Nginx + Static Frontend                    │  │
│  └────────────────────────┬───────────────────────────────┘  │
│                           │                                  │
│                           │ HTTP :5000                       │
│                           ▼                                  │
│  ┌────────────────────────────────────────────────────────┐  │
│  │ Private Subnet: 10.0.2.0/24                            │  │
│  │                                                        │  │
│  │   EC2 App Tier                                        │  │
│  │   Dockerized Python REST API                          │  │
│  └────────────────────────┬───────────────────────────────┘  │
└───────────────────────────┼──────────────────────────────────┘
                            │
                    VPC Peering Connection
                            │
                            ▼
┌──────────────────────────────────────────────────────────────┐
│                    VPC-B: data-vpc                           │
│                      10.1.0.0/16                             │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐  │
│  │ Private DB Subnets                                     │  │
│  │ 10.1.1.0/24        10.1.2.0/24                        │  │
│  │                                                        │  │
│  │          Amazon RDS PostgreSQL                         │  │
│  │                                                        │  │
│  │          Private / No Internet Access                  │  │
│  └────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────┘
```

### Request Flow

1. A user accesses the public IP of the Web Tier over HTTP.
2. Nginx serves the static frontend.
3. Requests to `/api/*` are reverse-proxied to the private App Tier on port `5000`.
4. The Dockerized REST API processes the request.
5. Database operations are sent through VPC Peering to the private RDS instance.
6. The database response travels back through the peering connection.
7. The App Tier can use the NAT Gateway for required outbound internet access.

---

## Key Features

* Three-tier cloud architecture.
* Separate application and database VPCs.
* Private application EC2 instance.
* Private RDS database.
* AWS VPC Peering between application and database VPCs.
* Nginx reverse proxy.
* Static frontend using HTML and vanilla JavaScript.
* Dockerized Python REST API.
* Product creation and listing.
* Health-check endpoint independent of the database.
* Automatic database schema creation.
* Terraform-based infrastructure provisioning.
* NAT Gateway for private-subnet internet egress.
* Multi-AZ RDS subnet group.
* Remote Terraform state using S3 and DynamoDB locking.
* Automated deployment through `script.sh`.

---

## Technology Stack

| Layer                  | Technology                |
| ---------------------- | ------------------------- |
| Cloud                  | Amazon Web Services       |
| Infrastructure as Code | Terraform >= 1.3          |
| Containers             | Docker                    |
| Web Server             | Nginx                     |
| Frontend               | HTML + Vanilla JavaScript |
| Backend                | Python REST API           |
| Database               | Amazon RDS PostgreSQL     |
| Networking             | Amazon VPC + VPC Peering  |
| State Management       | S3 + DynamoDB             |
| Compute                | Amazon EC2                |
| Egress                 | NAT Gateway               |
| Database Connectivity  | PostgreSQL / TCP 5432     |

---

## Project Structure

```text
nimbuscart/
├── app/
│   ├── frontend/
│   │   └── index.html
│   │
│   └── api/
│       ├── Dockerfile
│       ├── app.py
│       └── requirements.txt
│
├── terraform/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── backend.tf
│
├── script.sh
└── REPORT.md
```

### Important Files

| File                       | Purpose                                                    |
| -------------------------- | ---------------------------------------------------------- |
| `app/frontend/index.html`  | Static product catalog UI                                  |
| `app/api/app.py`           | REST API implementation and database schema initialization |
| `app/api/Dockerfile`       | Builds the API container                                   |
| `app/api/requirements.txt` | Python dependencies                                        |
| `terraform/main.tf`        | AWS infrastructure and provisioning                        |
| `terraform/variables.tf`   | Terraform configuration variables                          |
| `terraform/outputs.tf`     | Deployment outputs                                         |
| `terraform/backend.tf`     | Remote Terraform state configuration                       |
| `script.sh`                | Automated Terraform deployment                             |
| `REPORT.md`                | Architecture report and investigation findings             |

---

## Network Design

### Application VPC

**CIDR:** `10.0.0.0/16`

#### Public Subnet

**CIDR:** `10.0.1.0/24`

Contains:

* Internet Gateway connectivity.
* NAT Gateway.
* Elastic IP.
* Web Tier EC2 instance.

The Web Tier is the only application component directly exposed to inbound HTTP traffic.

#### Private Subnet

**CIDR:** `10.0.2.0/24`

Contains:

* App Tier EC2 instance.
* Dockerized REST API.

The App Tier is not directly exposed to the internet. Its inbound access is restricted to traffic originating from the Web Tier.

---

### Database VPC

**CIDR:** `10.1.0.0/16`

Database subnets:

* `10.1.1.0/24`
* `10.1.2.0/24`

The database VPC is intentionally isolated and does not use an Internet Gateway or NAT Gateway.

The RDS instance is reachable from the application VPC through VPC Peering.

---

## Application Tiers

### 1. Web Tier

The Web Tier runs on a public EC2 instance.

Responsibilities:

* Serve the static frontend.
* Accept HTTP requests from users.
* Reverse-proxy `/api/*` requests to the private App Tier.
* Prevent direct public access to the application server.

Nginx communicates with the App Tier over:

```text
Port 5000
```

---

### 2. App Tier

The App Tier runs on a private EC2 instance using Docker.

Responsibilities include:

* Processing REST API requests.
* Performing product CRUD operations.
* Connecting to PostgreSQL.
* Creating the required database schema during startup.

The application receives traffic from the Web Tier and uses the NAT Gateway for required outbound internet access.

---

### 3. Database Tier

The database tier consists of a private Amazon RDS PostgreSQL instance.

Database connectivity uses:

```text
TCP 5432
```

The database is isolated inside private subnets and is accessible only through the application network path.

---

## API Reference

### Health Check

```http
GET /health
```

Returns:

```json
{
  "status": "ok"
}
```

The health endpoint does not depend on database availability and can therefore be used for application health checks.

---

### List Products

```http
GET /items
```

Returns the products stored in the `products` table as a JSON array.

Example:

```json
[
  {
    "id": 1,
    "name": "Laptop",
    "price": 999.99,
    "stock": 10
  }
]
```

---

### Create Product

```http
POST /items
Content-Type: application/json
```

Request body:

```json
{
  "name": "Laptop",
  "price": 999.99,
  "stock": 10
}
```

The API inserts the product into the database and returns the created record, including its generated `id`.

---

## Prerequisites

Before deploying NimbusCart, install and configure:

* [AWS CLI](https://aws.amazon.com/cli/)
* [Terraform](https://developer.hashicorp.com/terraform/downloads) `>= 1.3.0`
* [Docker](https://docs.docker.com/get-docker/)
* An AWS SSH key pair in the deployment region.
* An S3 bucket for Terraform remote state.
* A DynamoDB table for Terraform state locking.
* AWS credentials with sufficient permissions to provision the required infrastructure.

Verify your AWS credentials:

```bash
aws sts get-caller-identity
```

Verify Terraform:

```bash
terraform version
```

Verify Docker:

```bash
docker --version
```

---

## AWS Infrastructure

Terraform provisions the infrastructure required for the complete deployment, including:

* Application VPC.
* Database VPC.
* Public and private subnets.
* Internet Gateway.
* NAT Gateway.
* Elastic IP.
* EC2 instances.
* Security groups.
* Route tables.
* VPC Peering.
* RDS database.
* Multi-AZ database subnet group.
* Deployment outputs.

---

## Configuration

### 1. Configure the Terraform Backend

Create the S3 bucket and DynamoDB locking table before initializing the main Terraform deployment.

Update `terraform/backend.tf`:

```hcl
terraform {
  backend "s3" {
    bucket         = "your-s3-bucket-name"
    key            = "nimbuscart/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "nimbuscart-tf-locks"
    encrypt        = true
  }
}
```

> The backend resources must exist before Terraform can use them as its remote state backend.

---

### 2. Configure Terraform Variables

Create `terraform/terraform.tfvars`:

```hcl
aws_region       = "us-east-1"
key_name         = "your-keypair-name"
db_username      = "nimbususer"
db_password      = "StrongDBPassword123!"
api_docker_image = "your-dockerhub-or-ecr-image:latest"
```

For real deployments, use a strong database password and avoid committing credentials to source control.

---

## Deployment

### Automated Deployment

From the repository root:

```bash
chmod +x script.sh
./script.sh
```

The deployment script automates:

```bash
terraform init
terraform plan
terraform apply -auto-approve
```

### Manual Deployment

Alternatively:

```bash
cd terraform

terraform init
terraform plan
terraform apply
```

Review the Terraform plan carefully before applying infrastructure in a production AWS account.

---

## Verification

After deployment, retrieve the Terraform outputs:

```bash
cd terraform
terraform output
```

The application can then be accessed using the generated frontend URL.

### Health Check

```bash
curl http://<web_public_ip>/api/health
```

Expected response:

```json
{
  "status": "ok"
}
```

The health endpoint has been verified to return HTTP `200` without requiring database initialization.

### Product API

List products:

```bash
curl http://<web_public_ip>/api/items
```

Create a product:

```bash
curl -X POST http://<web_public_ip>/api/items \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Laptop",
    "price": 999.99,
    "stock": 10
  }'
```

The frontend automatically refreshes after product creation.

---

## Terraform Outputs

A successful deployment exposes important infrastructure information:

| Output                  | Description                          |
| ----------------------- | ------------------------------------ |
| `web_public_ip`         | Public IPv4 address of the Web Tier  |
| `app_private_ip`        | Private IPv4 address of the App Tier |
| `db_endpoint`           | RDS connection endpoint              |
| `peering_connection_id` | VPC Peering connection ID            |
| `nat_gateway_public_ip` | NAT Gateway Elastic IP               |
| `frontend_url`          | HTTP URL for accessing NimbusCart    |

Retrieve individual values with:

```bash
terraform output web_public_ip
terraform output frontend_url
```

---

## Security

NimbusCart uses network segmentation to reduce the application's attack surface.

### Web Tier

The Web Tier is publicly reachable because it serves as the application's entry point.

### App Tier

The App Tier resides in a private subnet and accepts application traffic from the Web Tier rather than directly from the public internet.

### Database Tier

The database resides in private subnets with no direct internet connectivity.

Database traffic is restricted to the application network path over VPC Peering.

### Stateful Security Groups

Security Groups track connection state, allowing response traffic for established connections without requiring explicit return rules for every ephemeral port.

### NACL Considerations

Network ACLs are stateless. If NACLs are used to restrict PostgreSQL traffic, both the database port and appropriate ephemeral return ports must be permitted.

---

## Architecture Considerations

### VPC Peering

VPC Peering provides direct, non-transitive connectivity between the application and database VPCs.

This is appropriate for the relatively small topology used by NimbusCart.

For larger environments with many VPCs or shared VPN/Direct Connect connectivity, a centralized architecture such as AWS Transit Gateway may become more appropriate.

### NAT Gateway

The database tier does not require a NAT Gateway because it does not initiate public internet connections.

The App Tier, however, may require outbound internet access for activities such as retrieving packages or container artifacts. That traffic is routed through the NAT Gateway.

### Multi-AZ Database Subnets

The database subnet group spans two Availability Zones:

```text
10.1.1.0/24
10.1.2.0/24
```

This satisfies the RDS subnet-group requirement for multiple Availability Zones and provides the foundation for database availability and maintenance operations.

### Terraform `local-exec`

The deployment uses local execution for operations such as application image building/publishing.

A `local-exec` provisioner operates outside Terraform's normal resource-state tracking, so its side effects are not managed like native Terraform resources.

It is therefore best treated as a deployment/build step rather than a replacement for declarative infrastructure resources.

---

## Troubleshooting

### Database Connection Times Out

One important networking failure mode is a missing return route in the Data VPC.

The Data VPC needs a route similar to:

```text
10.0.0.0/16 → pcx-xxxxxxxx
```

Without the reciprocal route, the App Tier can send the TCP SYN to RDS, but the database cannot return the SYN-ACK.

The result is typically a connection timeout such as:

```text
ETIMEDOUT
```

---

### RDS Subnet Group Creation Fails

Ensure the RDS DB subnet group contains subnets in at least two Availability Zones.

NimbusCart uses:

```text
10.1.1.0/24
10.1.2.0/24
```

---

### App Tier Cannot Reach the Internet

Verify that:

1. The App Tier is in the private subnet.
2. The private route table has a default route to the NAT Gateway.
3. The NAT Gateway resides in the public subnet.
4. The public subnet has a route to the Internet Gateway.
5. The NAT Gateway has an associated Elastic IP.

---

### Terraform Backend Initialization Fails

The S3 state bucket and DynamoDB locking table must be available before running:

```bash
terraform init
```

The backend cannot bootstrap itself from the same state that it is responsible for storing.

---

## Database Schema

The application automatically creates the required `products` table when the API starts.

The schema provisioning uses:

```sql
CREATE TABLE IF NOT EXISTS
```

This allows the application to initialize its database structure when required.

---

## Testing

The following application behaviors have been verified:

* `GET /health` returns HTTP `200`.
* The health endpoint works independently of database initialization.
* The database schema is automatically created.
* Products can be created using `POST /items`.
* Product data can be retrieved using `GET /items`.
* The frontend refreshes after product creation.
* Application-to-database connectivity occurs through VPC Peering.

---

## Cleanup

AWS resources such as RDS, NAT Gateway, and Elastic IPs can incur charges.

Destroy the infrastructure when testing is complete:

```bash
cd terraform
terraform destroy -auto-approve
```

Review the destroy plan before confirming the operation.

> **Warning:** Destroying the infrastructure can permanently remove deployed resources and database data.

---

## Contributing

Contributions are welcome.

A typical workflow is:

```bash
git checkout -b feature/your-feature
```

Make your changes, test them locally, and submit a pull request describing:

* What changed.
* Why the change was needed.
* How it was tested.
* Any infrastructure or configuration implications.

---

## License

No license information is specified in the provided project materials.

If this repository is intended for public distribution, add an appropriate `LICENSE` file and update this section accordingly.

---

## Author

**Harshavardhan**
