# KijaniKiosk API Server - Desired State Specification

## Identity
- **Name:** `kijanikiosk-api-staging`
- **Environment tag:** `staging`
- **Owner tag:** `amina`

## Compute
- **Provider:** AWS
- **Region:** `af-south-1` (Cape Town)
- **Instance type:** `t3.micro`
- **Operating system:** `ubuntu-22.04-lts` 
- **Exact Image ID:** `ami-0c756f7efb0c95cc7` *(Note: Dynamic marketplace lookup filter: ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*)*

## Networking
- **VPC:** `10.0.0.0/16` (`vpc-0a12b34c56def7890`)
- **Subnet:** `10.0.1.0/24` (`subnet-0987654321fedcba0`)
- **Assign public IP:** Yes

## Access Control
- **SSH access:** Port 22, Source `197.232.0.50/32` (Amina's current local public IP)
- **HTTP access:** Port 80, Source `0.0.0.0/0` (Anywhere)
- **All other inbound:** Deny
- **All outbound:** Allow

## Storage
- **Root volume:** 8GB, type `gp3`, IOPS 3000, Throughput 125 MB/s

## Authentication
- **SSH key pair name:** `amina-kijanikiosk-staging-key`

## What must NOT exist on this server after provisioning
- **No Password Authentication:** `PasswordAuthentication no` must be explicitly asserted in `/etc/ssh/sshd_config`.
- **No Rogue Listeners:** No services or background binding daemons should occupy any ports other than `sshd` (22) and the target system stack components.
- **No World-Writable Paths:** Standard filesystem audits must ensure no permissive permissions (`chmod o+w`) exist on directory trees outside of `/tmp`.
- **No Default Root Access:** Direct root user logins over SSH via configuration flags must be completely forbidden (`PermitRootLogin no`).

## Open questions
1. **Dynamic vs Static Public IPs:** If this VM restarts, its public IP changes. Do we need an Elastic IP (EIP) or an attached AWS Application Load Balancer (ALB) to handle DNS persistence before moving to a shared layout?
2. **Key Rotation Lifecycle:** How do we safely manage and inject the public key via Terraform without hardcoding the key material or relying on manually pre-baked console keys?
3. **IAM Permissions:** Does this specific instance require an attached IAM Instance Profile role to talk securely to other cloud assets (like an S3 bucket or database)?

## Hardest Decision and Why
The hardest decision during the manual setup process was determining the correct networking architecture regarding **VPC Subnet selection** and **Public IP assignment**. Balancing immediate ease of access against core infrastructure security principles poses an engineering compromise. By choosing a public subnet and auto-assigning a public IP to facilitate straight SSH access, we expose our core VM directly to boundary sweeps on port 22. 

While restricting access to my specific source IP (`/32`) helps mitigate this issue, a production-grade infrastructure pattern would isolate the API server deep inside a private subnet, routing out via a NAT Gateway and handling inbound administrative connections securely through a Bastion Host, an AWS Systems Manager (SSM) Session Manager channel, or a corporate VPN gateway. Encoding this in code will force us to explicitly define these networking boundaries.
