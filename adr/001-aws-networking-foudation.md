# ADR-001: AWS VPC Networking Foundation for DevOps Environment

## Status

Accepted

---

## Context

The DevOps learning environment is being extended from a local Kubernetes platform towards AWS.

Terraform is used as the Infrastructure as Code tool responsible for provisioning AWS infrastructure.

The first AWS networking layer needs to provide a foundation for future workloads such as:

- EC2
- EKS
- Kubernetes worker nodes
- Load Balancers
- private application workloads

The network must distinguish between resources that require direct Internet connectivity and resources that should remain private.

Private resources should be able to initiate outbound connections to the Internet without requiring public IPv4 addresses.

The architecture should also introduce multi-AZ networking as preparation for highly available workloads.

---

## Decision

A dedicated VPC is created in the `eu-central-1` region using CIDR:

    10.0.0.0/16

The VPC is divided into public and private subnets across multiple Availability Zones.

The current network consists of:

    VPC
    10.0.0.0/16
    |
    +-- eu-central-1a
    |   |
    |   +-- public_a
    |   |   10.0.1.0/24
    |   |
    |   +-- private_a
    |       10.0.10.0/24
    |
    +-- eu-central-1b
        |
        +-- public_b
            10.0.2.0/24

---

## Public Subnets

Public subnets use a route table containing:

    10.0.0.0/16  -> local
    0.0.0.0/0    -> Internet Gateway

An Internet Gateway is attached to the VPC.

A subnet is considered public because its route table provides a route to the Internet Gateway.

The subnet itself does not contain a `public` or `private` flag.

---

## Private Subnets

Private subnets do not have a direct route to the Internet Gateway.

The private route table currently contains:

    10.0.0.0/16  -> local
    0.0.0.0/0    -> NAT Gateway

Resources deployed in the private subnet therefore use the NAT Gateway for outbound Internet connectivity.

Private resources do not receive public IPv4 addresses.

---

## NAT Gateway

A public NAT Gateway is deployed in `public_a`.

The NAT Gateway uses an Elastic IP.

The traffic flow is:

    Private EC2
        |
        v
    Private Route Table
        |
        | 0.0.0.0/0
        v
    NAT Gateway
        |
        v
    Public Route Table
        |
        v
    Internet Gateway
        |
        v
    Internet

The NAT Gateway performs address translation so that Internet-facing traffic uses its public address rather than the private IP address of the EC2 instance.

---

## Test EC2

A small EC2 instance is used to validate the networking architecture.

The instance is intentionally deployed in the private subnet.

Current configuration:

    Private IP:
    10.0.10.13

    Public IP:
    None

The EC2 instance is therefore dependent on the private route table and NAT Gateway for outbound Internet connectivity.

The instance is a temporary validation resource and is not considered part of the final production architecture.

---

## Security Groups

A Security Group is attached to the test EC2 instance.

The current lab Security Group allows:

    Ingress:
    TCP 80  -> 0.0.0.0/0
    TCP 443 -> 0.0.0.0/0

    Egress:
    All

This configuration is intentionally simplified for the networking laboratory.

Security Groups will be refined later when application-specific access patterns are introduced.

---

## High Availability

Two Availability Zones are used to establish the basic multi-AZ network structure.

Currently:

    eu-central-1a
        public_a
        private_a

    eu-central-1b
        public_b

Only one private subnet currently exists.

The architecture will later be extended with:

    eu-central-1b
        private_b

A decision about NAT Gateway redundancy will also be made later.

Possible architectures are:

    Single NAT Gateway
            |
            +-- private_a
            +-- private_b

or:

    NAT Gateway A          NAT Gateway B
          |                      |
      private_a              private_b

The second architecture provides better Availability Zone isolation but increases cost.

---

## Current Architecture

    Internet
        |
        v
    Internet Gateway
        |
        +----------------------+
        |                      |
        v                      v
    Public Route Table     NAT Gateway
    0.0.0.0/0 -> IGW           |
        |                      |
        +---------+------------+
                  |
                  v
            Private Route Table
            0.0.0.0/0 -> NAT
                  |
                  v
              private_a
             10.0.10.0/24
                  |
                  v
               Test EC2
              10.0.10.13
              No public IP

---

## Infrastructure as Code

All AWS networking resources are managed using Terraform.

Terraform is responsible for:

- VPC
- subnets
- route tables
- route table associations
- Internet Gateway
- NAT Gateway
- Elastic IP
- Security Groups
- test EC2 instance

Terraform represents the desired state of the AWS networking layer.

AWS remains responsible for creating and operating the underlying infrastructure.

---

## Alternatives Considered

### Direct Internet Gateway access from private subnets

Rejected.

Private resources should not have a direct default route to the Internet Gateway.

### Public IP addresses on private EC2 instances

Rejected.

This would remove the network-level separation between public and private workloads.

### NAT Instance

Rejected for the current architecture.

A NAT instance would require management of an EC2-based NAT solution, including:

- operating system
- patching
- availability
- scaling
- routing
- failure handling

AWS-managed NAT Gateway is preferred for this learning architecture.

### Single AZ architecture

Rejected.

The environment is intended to prepare for EKS and production-style AWS deployments, where multi-AZ architecture is a fundamental concept.

---

## Consequences

### Positive

- Public and private workloads are clearly separated.
- Private EC2 instances do not require public IP addresses.
- Private workloads can initiate outbound Internet connections.
- The network provides a foundation for EKS.
- Multi-AZ concepts are introduced from the beginning.
- The entire network is reproducible through Terraform.

### Negative

- NAT Gateway introduces additional AWS cost.
- The current architecture has only one NAT Gateway.
- `private_b` has not yet been created.
- The current Security Group is intentionally permissive.
- The test EC2 is not yet production-oriented.
- The architecture has not yet been validated end-to-end from inside the private EC2.

---

## Validation Status

The following has been verified using AWS CLI:

- VPC exists.
- Public subnets exist.
- Private subnet exists.
- Public route table routes `0.0.0.0/0` to the Internet Gateway.
- Private route table routes `0.0.0.0/0` to the NAT Gateway.
- NAT Gateway is `available`.
- NAT Gateway has an Elastic IP.
- Test EC2 is running in the private subnet.
- Test EC2 has no public IP.

The following has not yet been verified:

    Private EC2
        |
        v
    NAT Gateway
        |
        v
    Internet

End-to-end outbound Internet connectivity from the private EC2 remains to be tested.

---

## Next Steps

### 1. Verify outbound Internet connectivity

Access the private EC2 and verify:

    Private EC2 -> Internet

The public IP observed from the Internet should correspond to the NAT Gateway's Elastic IP.

This will provide an end-to-end validation of:

    Private Route Table
            |
            v
        NAT Gateway
            |
            v
        Internet Gateway
            |
            v
          Internet

### 2. Enable private EC2 administration

The current EC2 instance cannot yet be accessed through AWS Systems Manager.

Investigate:

- IAM Role
- Instance Profile
- Systems Manager permissions
- SSM Agent
- network connectivity to SSM endpoints

This will introduce the relationship between:

    EC2
     |
     +-- IAM Role
     |
     +-- SSM Agent
     |
     +-- Network connectivity
     |
     v
    AWS Systems Manager

### 3. Add the second private subnet

Create:

    private_b
    10.0.20.0/24

in:

    eu-central-1b

Associate it with the private route table.

### 4. Re-evaluate NAT Gateway architecture

Compare:

    1 NAT Gateway

against:

    1 NAT Gateway per AZ

based on:

- availability
- failure domains
- cost
- operational complexity

### 5. Prepare the network for EKS

After the networking fundamentals are validated, extend the architecture towards:

    VPC
    |
    +-- Public subnets
    |     |
    |     +-- Internet-facing Load Balancers
    |     +-- NAT Gateways
    |
    +-- Private subnets
          |
          +-- EKS worker nodes
          +-- Kubernetes workloads

EKS-specific networking and IAM decisions will be introduced only after the current VPC architecture is fully understood and validated.
