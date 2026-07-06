# Manual Provisioning Decisions - KijaniKiosk API Server

| Decision          | Value I chose | Reason |
|-------------------|---------------|--------|
| **Cloud provider** | AWS (Amazon Web Services) | Selected due to robust Free Tier availability, broad tooling compatibility, and regional presence in Africa. |
| **Region** | `af-south-1` (Cape Town) | Geographically closest AWS region to Nairobi, Kenya, offering the lowest network latency for KijaniKiosk users. |
| **Operating system** | Ubuntu Server 22.04 LTS (HVM), SSD Volume Type | Required by engineering specs; LTS ensures long-term stability and security patch availability. |
| **Instance type** | `t3.micro` | Lowest cost eligible tier in Cape Town that provides bursts of CPU performance sufficient for development workloads. |
| **VPC** | `vpc-0a12b34c56def7890` (KijaniKiosk-Staging-VPC) | Isolates our application ecosystem cleanly away from the default cloud network space. |
| **Subnet** | `subnet-0987654321fedcba0` (Public-Subnet-1A) | Placed in a public-facing subnet with an internet gateway attached so Nginx can route traffic inwards. |
| **Security group** | `sg-0123456789abcdef0` (kk-api-sg) | Acts as an immediate stateful firewall protecting the host network perimeter. |
| **SSH key pair** | `amina-kijanikiosk-staging-key` | Essential for public-key authentication; ensures password login can be safely shut off. |
| **Root volume size** | `8 GB` General Purpose SSD (`gp3`) | Default standard sizing for Ubuntu baseline operations, balanced for throughput and cost efficiency. |
| **Public IP?** | Enabled (Auto-assign Public IP) | Required temporarily so developers can SSH in directly and traffic can arrive from the public internet. |
| **Tags / labels** | `Name: assignment-api-staging`, `Env: staging`, `Owner: amina` | Enforces structural tracking, resource accountability, and deterministic querying via code later. |
