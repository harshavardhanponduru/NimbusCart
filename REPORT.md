# NimbusCart: Automated Three-Tier AWS Infrastructure Deployment

## 1. Abstract
This project implements **NimbusCart**, a resilient three-tier cloud architecture on AWS automated entirely with Terraform and containerized via Docker. The infrastructure enforces strict security isolation across decoupled Virtual Private Clouds (VPCs) connected via inter-VPC Peering.

---

## 2. Architectural Design & Network Topology
The system architecture isolates tiers across two dedicated VPCs:

* **VPC-A (`app-vpc` - `10.0.0.0/16`):**
  * **Public Subnet (`10.0.1.0/24`):** Hosts the Web Tier (Nginx server hosting static frontend assets and reverse proxying `/api/` traffic) and the NAT Gateway.
  * **Private Subnet (`10.0.2.0/24`):** Hosts the App Tier (Dockerized REST API). Inbound traffic is restricted to the Web Tier Security Group. Outbound internet egress routes through the NAT Gateway.
* **VPC-B (`data-vpc` - `10.1.0.0/16`):**
  * **Database Subnets (`10.1.1.0/24`, `10.1.2.0/24`):** Dedicated to a private PostgreSQL RDS instance. Completely isolated with no internet gateway or NAT attachments. Accessible only from VPC-A via AWS VPC Peering.

---

## 3. Conceptual & Investigative Findings

### Task A Findings
1. **Missing Return Route in Data VPC:**
   * IP networking is bidirectional. If the return route (`10.0.0.0/16 -> pcx-...`) is missing from `data-vpc`'s route table, the App Tier can transmit the initial TCP SYN packet to RDS, but the database cannot route the TCP SYN-ACK reply back.
   * **Result:** Client connections hang indefinitely and fail with `ETIMEDOUT`.
2. **Why DB Subnet Needs No NAT Gateway:**
   * A NAT Gateway converts private IP requests to public egress to access public internet endpoints.
   * The database subnet only acts as a **responder** to private connections initiated by the App Tier across internal VPC peering routes. Because it never needs to initiate outbound internet connections, a NAT Gateway is unnecessary.

### Task C Analysis
1. **Multi-AZ DB Subnet Group Requirement:**
   * AWS RDS requires DB Subnet Groups to span at least two Availability Zones even for single-AZ instances to allow seamless failover, non-disruptive storage scaling, and zero-downtime maintenance transitions. Without 2+ AZs, `aws_db_subnet_group` creation fails with `InvalidParameterValue`.
2. **VPC Peering vs. AWS Transit Gateway:**
   * VPC Peering provides 1:1 non-transitive routing with no single point of failure or bandwidth bottlenecks, making it ideal and cost-free for 2–3 VPCs.
   * A Transit Gateway acts as a central hub-and-spoke router and should replace VPC peering once an organization scales to 5+ VPCs, complex mesh topologies, or shared corporate VPN/Direct Connect connections.
3. **App Tier Authentication and ECR/Docker Pulling via NAT Gateway:**
   * The App EC2 instance resolves AWS endpoints via AWS DNS, sends outgoing HTTPS requests through the Private Subnet route table directed at the NAT Gateway ENI (`10.0.1.0/24`), which substitutes the source IP with its Elastic IP to pull packages from the internet and return packets to the private instance.
4. **Stateful Security Groups vs Stateless NACLs:**
   * Security Groups automatically track connection state and allow return traffic on ephemeral ports.
   * Network Access Control Lists (NACLs) are stateless. If you open inbound port 5432 in a NACL but forget to open outbound ephemeral ports (`1024-65535`), PostgreSQL replies cannot return, breaking database traffic completely.
5. **Trade-offs of `local-exec` Provisioners:**
   * `local-exec` executes outside of Terraform's state engine; Terraform cannot track side effects, drift, idempotency, or successful execution.
   * It is acceptable for local image builds here because the Docker image artifact is stateless and acts only as a build-and-push step prior to deployment.
6. **Backend Bootstrapping Problem:**
   * Terraform cannot store state inside an S3 bucket or lock via DynamoDB if those exact resources are defined in the same state file that requires them to run. The backend infrastructure must be provisioned first as independent foundational infrastructure.

---

## 4. Verification & Testing Evidence
* `GET /health` returns `HTTP 200 {"status": "ok"}` without database initialization.
* Table auto-creation verified via runtime dynamic schema provisioning (`CREATE TABLE IF NOT EXISTS`).
* Product creation via `POST /items` confirmed with automatic UI refresh in the Web Tier frontend.