# PetClinic AWS Infrastructure

[![Terraform](https://img.shields.io/badge/Terraform-1.6%2B-7B42BC?logo=terraform&logoColor=white)](https://www.terraform.io/)
[![AWS](https://img.shields.io/badge/AWS-Cloud-FF9900?logo=amazon-aws&logoColor=white)](https://aws.amazon.com/)
[![Amazon EKS](https://img.shields.io/badge/Amazon-EKS-326CE5?logo=kubernetes&logoColor=white)](https://aws.amazon.com/eks/)

Terraform infrastructure for the Spring PetClinic application running on Amazon EKS.

The project uses an **ephemeral environment** that can be quickly created for development/testing and completely destroyed when no longer needed.

## Infrastructure

- AWS VPC
- Amazon EKS
- EC2
- RDS PostgreSQL
- AWS Secrets Manager
- Route 53
- AWS Load Balancer Controller
- ExternalDNS
- External Secrets Operator
- EKS Pod Identity

## Deployment

### Bootstrap

Create the complete ephemeral environment:

    ./bootstrap/bootstrap.sh

### Destroy

Destroy the complete environment:

    ./bootstrap/destroy-environment.sh

## Architecture

    Internet
       │
       ▼
    Internet Gateway
       │
       ▼
    Public Subnets
       │
       ▼
    NAT Gateway
       │
       ▼
    Private Subnets
       │
       ├── EKS Nodes
       │      │
       │      └── PetClinic
       │
       └── RDS PostgreSQL
