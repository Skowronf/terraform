# ADR-001: AWS VPC Networking Foundation for DevOps Environment

## Status

Accepted

---

## Context

The DevOps learning environment is being extended from a local Kubernetes platform towards AWS.

Terraform is used as the Infrastructure as Code tool responsible for provisioning AWS infrastructure.

The AWS networking layer needs to provide a foundation for future workloads such as:

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

The VPC is divided into public and private subnets across two Availability Zones.

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
        |   10.0.2.0/24
        |
        +-- private_b
            10.0.11.0/24

Both Availability Zones contain a public and a private subnet.

The architecture currently uses:

- one Internet Gateway
- one public route table shared by both public subnets
- one private route table shared by both private subnets
- one NAT Gateway located in `public_a`
- one Elastic IP associated with the NAT Gateway

---

## Public Subnets

The following public subnets exist:

    public_a
    10.0.1.0/24
    eu-central-1a

    public_b
    10.0.2.0/24
    eu-central-1b

Both public subnets are associated with the same public route table.

The public route table contains:

    10.0.0.0/16  -> local
    0.0.0.0/0    -> Internet Gateway

An Internet Gateway is attached to the VPC.

A subnet is considered public because its associated route table provides a route to the Internet Gateway.

The subnet itself does not contain a `public` or `private` flag.

Resources deployed in a public subnet can communicate with the Internet when they have a public IPv4 address and the appropriate security rules.

---

## Private Subnets

The following private subnets exist:

    private_a
    10.0.10.0/24
    eu-central-1a

    private_b
    10.0.11.0/24
    eu-central-1b

Both private subnets are associated with the same private route table.

The private route table contains:

    10.0.0.0/16  -> local
    0.0.0.0/0    -> NAT Gateway

Private subnets therefore do not have a direct route to the Internet Gateway.

Resources deployed in the private subnets can initiate outbound Internet connections through the NAT Gateway.

Private resources do not require public IPv4 addresses for outbound Internet connectivity.

---

## NAT Gateway

A public NAT Gateway is deployed in `public_a` in Availability Zone `eu-central-1a`.

The NAT Gateway uses an Elastic IP.

The current architecture contains only one NAT Gateway.

Both private subnets use the same private route table, which routes Internet-bound traffic through this NAT Gateway.

The traffic flow is:

    Private EC2
        |
        v
    Private Route Table
        |
        | 0.0.0.0/0
        v
    NAT Gateway
    eu-central-1a
        |
        v
    Public Route Table
        |
        v
    Internet Gateway
        |
        v
    Internet

The NAT Gateway performs address translation so that Internet-facing traffic uses its public Elastic IP rather than the private IP address of the EC2 instance.

---

## NAT Gateway and Availability Zone Design

The current architecture intentionally uses a single NAT Gateway for both Availability Zones.

Traffic from both:

    private_a
    private_b

is routed through:

    NAT Gateway
    eu-central-1a

This design reduces AWS cost and keeps the initial networking architecture simple.

However, it introduces an Availability Zone dependency.

If `eu-central-1a` or the NAT Gateway becomes unavailable, private workloads in both Availability Zones may lose outbound Internet connectivity.

The current architecture therefore provides multi-AZ subnet structure but does not provide fully redundant NAT connectivity.

A future production-oriented architecture may deploy one NAT Gateway per Availability Zone:

    eu-central-1a

        public_a
            |
        NAT Gateway A
            |
        private_a


    eu-central-1b

        public_b
            |
        NAT Gateway B
            |
        private_b

This architecture provides better Availability Zone isolation but increases cost.

---

## Test EC2

A small EC2 instance is used to validate the networking architecture.

The instance is intentionally deployed in a private subnet.

The test EC2 does not receive a public IPv4 address.

The instance therefore depends on:

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

for outbound Internet connectivity.

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

The Security Group is separate from subnet routing.

Network routing determines where traffic can go, while Security Groups control allowed traffic at the resource level.

---

## High Availability

Two Availability Zones are used:

    eu-central-1a
    eu-central-1b

Each Availability Zone currently contains one public and one private subnet.

The current structure is:

    eu-central-1a
        public_a
        private_a

    eu-central-1b
        public_b
        private_b

This provides the basic subnet structure required for future highly available workloads such as EKS.

However, the NAT layer is not currently redundant.

Both private subnets use the same NAT Gateway located in `eu-central-1a`.

Therefore:

- subnet-level multi-AZ architecture is implemented
- NAT Gateway redundancy is not implemented
- private subnet outbound Internet traffic currently depends on a single NAT Gateway

A future decision will determine whether the environment should use:

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
        v
    Public Route Table
    0.0.0.0/0 -> IGW
        |
        +----------------------+
        |                      |
        v                      v
    public_a               public_b
    10.0.1.0/24            10.0.2.0/24
    eu-central-1a           eu-central-1b
        |
        v
    NAT Gateway
    eu-central-1a
        |
        v
    Private Route Table
    0.0.0.0/0 -> NAT
        |
        +----------------------+
        |                      |
        v                      v
    private_a              private_b
    10.0.10.0/24            10.0.11.0/24
    eu-central-1a           eu-central-1b
        |
        v
    Private workloads
    / Test EC2
    No public IP

---

## Route Table Design

The public route table is shared by:

    public_a
    public_b

Its Internet-bound traffic is routed through the Internet Gateway.

The private route table is shared by:

    private_a
    private_b

Its Internet-bound traffic is routed through the NAT Gateway.

Conceptually:

    Public subnets
        |
        v
    Public Route Table
        |
        v
    Internet Gateway


    Private subnets
        |
        v
    Private Route Table
        |
        v
    NAT Gateway
        |
        v
    Internet Gateway

The route table associations are managed explicitly using Terraform.

---

## Infrastructure as Code

All AWS networking resources are managed using Terraform.

Terraform is responsible for:

- VPC
- public subnets
- private subnets
- public route table
- private route table
- route table associations
- Internet Gateway
- NAT Gateway
- Elastic IP
- Security Groups
- test EC2 instance

The current Terraform networking layer defines:

    VPC:
    10.0.0.0/16

    Public:
    10.0.1.0/24  -> eu-central-1a
    10.0.2.0/24  -> eu-central-1b

    Private:
    10.0.10.0/24 -> eu-central-1a
    10.0.11.0/24 -> eu-central-1b

    NAT:
    public_a / eu-central-1a

Terraform represents the desired state of the AWS networking layer.

AWS remains responsible for creating and operating the underlying infrastructure.

---

## Alternatives Considered

### Direct Internet Gateway access from private subnets

Rejected.

Private resources should not have a direct default route to the Internet Gateway.

Outbound Internet access from private resources should use a NAT Gateway.

### Public IP addresses on private EC2 instances

Rejected.

Private resources should remain without public IPv4 addresses.

This preserves the network-level separation between public and private workloads.

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

### One NAT Gateway per Availability Zone

Not implemented yet.

A NAT Gateway per Availability Zone would improve Availability Zone isolation and resilience, but would increase AWS costs.

For the current learning environment, a single NAT Gateway is an intentional cost optimization.

This decision can be revisited when the environment moves towards a production-oriented architecture.

---

## Consequences

### Positive

- Public and private workloads are clearly separated.
- Both Availability Zones contain public and private subnets.
- Private EC2 instances do not require public IP addresses.
- Private workloads can initiate outbound Internet connections through the NAT Gateway.
- The network provides a foundation for EKS.
- Multi-AZ networking concepts are introduced from the beginning.
- The entire network is reproducible through Terraform.
- A single NAT Gateway keeps the initial AWS cost lower.

### Negative

- NAT Gateway introduces additional AWS cost.
- The current architecture has only one NAT Gateway.
- Both private subnets depend on a NAT Gateway located in `eu-central-1a`.
- Loss of the NAT Gateway or its Availability Zone can affect outbound Internet connectivity from both private subnets.
- The current Security Group is intentionally permissive.
- The test EC2 is not production-oriented.
- End-to-end outbound Internet connectivity from the private EC2 must still be validated.

---

## Validation Status

The following infrastructure components are defined and should be verified using AWS CLI or Terraform:

- VPC exists.
- Public subnet `public_a` exists.
- Public subnet `public_b` exists.
- Private subnet `private_a` exists.
- Private subnet `private_b` exists.
- Both public subnets are associated with the public route table.
- Both private subnets are associated with the private route table.
- Public route table routes `0.0.0.0/0` to the Internet Gateway.
- Private route table routes `0.0.0.0/0` to the NAT Gateway.
- NAT Gateway is located in `public_a`.
- NAT Gateway uses an Elastic IP.
- Test EC2 is deployed in a private subnet.
- Test EC2 has no public IP.

The following end-to-end behavior remains to be validated:

    Private EC2
        |
        v
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

Outbound Internet connectivity from the private EC2 should be tested explicitly.

---

## Next Steps

### 1. Verify outbound Internet connectivity

Access the private EC2 and verify:

    Private EC2 -> Internet

For example, verify connectivity using an appropriate HTTP/HTTPS request.

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

The current EC2 instance should be administered through AWS Systems Manager rather than requiring a public IP or bastion host.

Investigate:

- IAM Role
- Instance Profile
- Systems Manager permissions
- SSM Agent
- network connectivity to required AWS endpoints

This introduces the relationship between:

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

### 3. Validate both private subnets

Confirm that workloads placed in both:

    private_a
    private_b

can use the private route table and reach the Internet through the NAT Gateway.

This validates that the shared private route table works correctly across Availability Zones.

### 4. Re-evaluate NAT Gateway architecture

Compare:

    1 NAT Gateway
        |
        +-- private_a
        +-- private_b

against:

    NAT Gateway A          NAT Gateway B
          |                      |
      private_a              private_b

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

---

## Summary

The current AWS networking foundation provides a two-AZ VPC with separate public and private subnets.

The public subnets use the Internet Gateway for Internet connectivity.

The private subnets use a shared private route table with a default route to a single NAT Gateway located in `eu-central-1a`.

The architecture therefore provides:

    Multi-AZ subnet structure
            +
    Public / private separation
            +
    Private outbound Internet access
            +
    Terraform-managed infrastructure

The main remaining architectural limitation is the single NAT Gateway.

This is an intentional cost optimization for the current DevOps learning environment and can be revisited when higher availability becomes a requirement.
