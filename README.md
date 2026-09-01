## Step 1: Creating the Base Virtual Private Cloud (VPC)

### Concept
A Virtual Private Cloud (VPC) provides an isolated virtual network within AWS to host infrastructure securely. To ensure proper IP address management, we assign a `/16` private CIDR block, giving us 65,536 available addresses that can be sub-divided into smaller subnets later.

### Implementation Steps
1. Navigated to the **VPC Dashboard** in the AWS Console.
2. Selected **Create VPC** with the **VPC only** option to manage step-by-step creation manually.
3. Configured the core parameters:
   - **Name Tag:** `secure-lab-vpc`
   - **IPv4 CIDR Block:** `10.0.0.0/16`
   - **Tenancy:** Default
4. Enabled **DNS Hostnames** and **DNS Resolution** under VPC settings to ensure instances receive public DNS records upon launch.

![VPC Creation Details](images/01-vpc-setup.png)

## Step 2: Subnetting & Network Segmentation

### Concept
To enforce network security through isolation, we divide our `/16` network into dedicated `/24` subnets (256 addresses each). 

- **Public Subnet:** Hosts internet-facing applications (web servers). Auto-assign public IPv4 is enabled here.
- **Private Subnet:** Hosts sensitive backend infrastructure (databases) with no direct ingress paths from the outside world.

### Implementation Steps
1. Navigated to **Subnets** in the VPC Dashboard and bound them to `secure-lab-vpc`.
2. Created **`public-subnet-1`**:
   - **CIDR:** `10.0.1.0/24`
   - **Availability Zone:** `us-east-1a`
3. Created **`private-subnet-1`**:
   - **CIDR:** `10.0.2.0/24`
   - **Availability Zone:** `us-east-1a`
4. Modified settings for `public-subnet-1` to enable **Auto-assign public IPv4 address**.

![Subnet Setup Details](images/02-subnets-setup.png)

## Step 3: Internet Routing Setup

### Concept
Subnets are isolated by default. To make `public-subnet-1` internet-accessible, we attach an Internet Gateway (IGW) to the VPC and configure a custom Route Table. 

- **Default Route (`10.0.0.0/16 -> local`):** Allows resources within the VPC to communicate with each other.
- **Internet Route (`0.0.0.0/0 -> IGW`):** Directs any outbound/inbound internet traffic through the IGW.

`private-subnet-1` remains unassociated with this route table, maintaining its private status.

### Implementation Steps
1. Created an Internet Gateway named **`secure-lab-igw`** and attached it to `secure-lab-vpc`.
2. Created a custom Route Table named **`public-route-table`** bound to `secure-lab-vpc`.
3. Added a route to destination `0.0.0.0/0` pointing to `secure-lab-igw` as the target.
4. Associated **`public-subnet-1`** with `public-route-table`.

![Public Route Table Configuration](images/03-public-route-table.png)

## Step 4: Network Security & Firewall Configuration

### Concept
AWS Security Groups function as stateful virtual firewalls filtering traffic at the instance level. Applying the principle of least privilege, we block all inbound access by default and explicitly permit only required application ports.

- **Port 22 (SSH):** Configured for administrative management via EC2 Instance Connect / Administrator IP.
- **Port 80 (HTTP) & Port 443 (HTTPS):** Opened globally (`0.0.0.0/0`) for web client ingress.

### Implementation Steps
1. Navigated to **Security Groups** in the VPC Dashboard and clicked **Create security group**.
2. Configured basic parameters:
   - **Name:** `web-server-sg`
   - **VPC:** `secure-lab-vpc`
3. Configured inbound rules:
   - Added **SSH** (TCP/22) for initial administrative setup.
   - Added **HTTP** (TCP/80) originating from `0.0.0.0/0`.
   - Added **HTTPS** (TCP/443) originating from `0.0.0.0/0`.
4. Retained default outbound rules permitting all egress traffic.

![Security Group Inbound Rules](images/04-security-group-rules.png)


## Step 5: Web Server Provisioning & SSL/TLS Encryption

### Concept
With network security configured, we deploy an EC2 instance running Amazon Linux 2023 inside the public subnet. To resolve repository domains and download packages, DNS resolution must be enabled at the VPC level. We install the Apache web daemon (`httpd`) along with `mod_ssl` to serve incoming web traffic. To protect data in transit without a registered domain, we generate an RSA 2048-bit self-signed X.509 certificate to encrypt web traffic on TCP port 443. Following configuration, SSH access is hardened according to least privilege practices.

### Implementation Steps
1. Configured **`secure-lab-vpc`** settings to enable **DNS Resolution** and **DNS Hostnames**.
2. Launched an EC2 instance with the following specifications:
   - **Name:** `secure-web-server`
   - **Subnet:** `public-subnet-1`
   - **Security Group:** `web-server-sg`
3. Connected via EC2 Instance Connect to install Apache, configure SSL, and create the landing page:
   ```bash
   sudo dnf update -y
   sudo dnf install -y httpd mod_ssl
   sudo systemctl start httpd
   sudo systemctl enable httpd
   echo '<h1>Welcome to Secure AWS Lab Web Server!</h1>' | sudo tee /var/www/html/index.html
   sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
     -keyout /etc/pki/tls/private/apache-selfsigned.key \
     -out /etc/pki/tls/certs/apache-selfsigned.crt
   sudo systemctl restart httpd

![Server Live ](images/05-web-server-live.png)

## Step 6: Resource Teardown & Environment Cleanup

### Concept
To adhere to cloud cost-optimization best practices and prevent unnecessary charges, all manually provisioned resources must be decommissioned in reverse order of creation. Removing instances first releases elastic network interface (ENI) dependencies, allowing subnets, security groups, route tables, and the parent VPC to be deleted cleanly.

### Implementation Steps
1. **Terminated Compute Layer:**
   - Navigated to **EC2 Console** $\rightarrow$ **Instances**.
   - Selected `secure-web-server` $\rightarrow$ **Instance state** $\rightarrow$ **Terminate instance**.
   - Verified the instance reached a `Terminated` state to free network interface attachments.
2. **Decommissioned Internet Gateway:**
   - Navigated to **Internet Gateways** $\rightarrow$ Selected `secure-lab-igw`.
   - Executed **Detach from VPC**, then permanently deleted the gateway.
3. **Removed Network Security Rules:**
   - Navigated to **Security Groups** $\rightarrow$ Selected and deleted `web-server-sg`.
4. **Deleted Virtual Private Cloud (VPC):**
   - Navigated to **Your VPCs** $\rightarrow$ Selected `secure-lab-vpc` $\rightarrow$ **Actions** $\rightarrow$ **Delete VPC**.
   - Confirmed full deletion, automatically purging associated subnets (`public-subnet-1`, `private-subnet-1`), route tables, and default security groups.

![Resource Teardown Verification](images/06-resource-cleanup.png)