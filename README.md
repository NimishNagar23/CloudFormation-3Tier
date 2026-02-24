# AWS 3-Tier Nested CloudFormation Architecture

This repository contains an infrastructure-as-code (IaC) implementation of a highly available, secure, and scalable 3-Tier Web Architecture on AWS using CloudFormation nested stacks. 

## 🏗️ Architecture Overview

The architecture is split into five modular, nested CloudFormation templates orchestrated by a single root stack (`root_stack.yaml`). 

### Components

1. **Network Tier (`vpc-stack.yaml`)**
   - 1 Virtual Private Cloud (VPC)
   - 1 Internet Gateway (IGW)
   - 2 Public Subnets (for Web Tier resources)
   - 4 Private Subnets (2 for App Tier, 2 for Database Tier)
   - 1 NAT Gateway with Elastic IP (for secure outbound internet access from private subnets)
   - Route Tables and associations mapping public vs private traffic.

2. **Security Tier (`security-stack.yaml`)**
   - **ALB Security Group:** Allows external HTTP/HTTPS traffic (ports 80/443).
   - **Web Security Group:** Allows traffic from the ALB.
   - **App Security Group:** Isolated; only allows traffic originating from the Web Security Group.
   - **DB Security Group:** Isolated; only allows traffic originating from the App Security Group.

3. **Web Tier (`web-stack.yaml`)**
   - Internet-facing Application Load Balancer (ALB).
   - Auto Scaling Group (ASG) deploying EC2 instances across Public Subnets.

4. **App Tier (`app-stack.yaml`)**
   - Internal Application Load Balancer (ALB) to route traffic from Web to App.
   - Auto Scaling Group (ASG) deploying EC2 instances across Private Subnets (App layer).

5. **Database Tier (`db-stack.yaml`)**
   - AWS RDS MySQL Instance deployed securely within a DB Subnet Group spanning Private Subnets.

## 🚀 Deployment

The deployment process leverages AWS CloudFormation nested stacks. All inner stacks are securely referenced via an S3 Bucket.

### Prerequisites
- AWS CLI installed and configured (`aws configure`)
- IAM permissions to create VPCs, EC2 instances, ALBs, NAT Gateways, RDS, etc.
- An existing EC2 Key Pair in your chosen AWS Region.

### 1. Upload Templates to S3 (Using `deploy.sh`)

Because the root stack relies on `TemplateURL` properties, the nested child stacks must be packaged and uploaded to S3 first. 

You can use the provided bash script which automatically creates a CFN-packaging S3 Bucket, syncs local files to it, and runs the AWS deployment:

```bash
chmod +x deploy.sh
./deploy.sh <Your-EC2-KeyPair-Name>
```

### 2. Manual Deployment (Alternative)

If you prefer to deploy manually via the CLI, you must first upload the `.yaml` files to your own S3 bucket, modify `root_stack.yaml` to point to your S3 bucket URLs, and then run:

```bash
aws cloudformation create-stack \
  --stack-name My-3Tier-Stack \
  --template-url https://<your-s3-bucket-url>/root_stack.yaml \
  --capabilities CAPABILITY_NAMED_IAM CAPABILITY_AUTO_EXPAND \
  --parameters \
      ParameterKey=EnvironmentName,ParameterValue=3Tier \
      ParameterKey=InstanceType,ParameterValue=t2.micro \
      ParameterKey=KeyName,ParameterValue=<Your-Key-Pair> \
      ParameterKey=DBUsername,ParameterValue=admin \
      ParameterKey=DBPassword,ParameterValue=<Strong-Password>
```

## 🧹 Cleanup

To avoid incurring unwanted AWS charges (especially for NAT Gateways, Load Balancers, and RDS), thoroughly delete the stack once prototyping is complete.

```bash
aws cloudformation delete-stack --stack-name My-3Tier-Stack
```

> **Note:** The RDS database in this template has `DeletionPolicy: Delete` enabled to prevent snapshot accumulation during deletion. Do not use this specific RDS deployment configuration directly in production without removing `DeletionPolicy: Delete` and configuring Multi-AZ.
