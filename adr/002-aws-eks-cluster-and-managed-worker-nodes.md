# ADR-002: AWS EKS Cluster and Managed Worker Nodes

## Status

Accepted

---

## Context

The AWS environment needs to provide a managed Kubernetes platform for workloads that were previously running locally on Kubernetes.

Amazon EKS is used as the managed Kubernetes control plane.

The architecture also requires worker nodes capable of running Kubernetes workloads.

AWS IAM is used to provide separate identities and permissions for:

- EKS Control Plane
- EKS worker nodes

The goal is to keep the responsibilities and permissions of the control plane and worker nodes separate.

---

## Decision

Use Amazon EKS with:

- AWS-managed Kubernetes Control Plane
- EKS Managed Node Group
- dedicated IAM Role for the EKS Control Plane
- dedicated IAM Role for EKS worker nodes
- worker nodes deployed in private subnets
- worker nodes distributed across two Availability Zones

Current architecture:

    EKS Cluster
    |
    +-- AWS-managed Control Plane
    |
    +-- Managed Node Group
        |
        +-- EC2 Node
        |
        +-- EC2 Node

Worker nodes are deployed into:

    private_a
    eu-central-1a

    private_b
    eu-central-1b

---

## EKS Cluster IAM Role

A dedicated IAM Role is used by the EKS Control Plane.

Terraform resource:

    aws_iam_role.eks_cluster

AWS Role name:

    petclinic-eks-cluster-role

The role contains:

    Trust Policy
        |
        | EKS can assume the role
        v
    eks.amazonaws.com

The role has:

    AmazonEKSClusterPolicy

Mental model:

    EKS Control Plane
            |
            | AssumeRole
            v
    EKS Cluster IAM Role
            |
            | permissions
            v
        AWS APIs

The Cluster IAM Role is not used by worker nodes.

---

## EKS Node IAM Role

Worker nodes use a separate IAM Role.

Terraform resource:

    aws_iam_role.eks_node

AWS Role name:

    petclinic-eks-node-role

The trust policy allows:

    ec2.amazonaws.com

to assume the role.

The role currently has:

    AmazonEKSWorkerNodePolicy
    AmazonEC2ContainerRegistryPullOnly

Mental model:

    EC2 Node
       |
       | AssumeRole
       v
    Node IAM Role
       |
       +-- EKS permissions
       |
       +-- ECR pull permissions

The Node IAM Role is separate from the EKS Cluster IAM Role.

---

## IAM Mental Model

An IAM Role has two important concepts:

    Trust Policy
        |
        | WHO can assume the role?
        v

    IAM Role

        |

    Permissions
        |
        | WHAT can the role do?
        v

    AWS APIs / Resources

For the EKS Cluster:

    Trust:
    eks.amazonaws.com

    Permissions:
    AmazonEKSClusterPolicy

For worker nodes:

    Trust:
    ec2.amazonaws.com

    Permissions:
    AmazonEKSWorkerNodePolicy
    AmazonEC2ContainerRegistryPullOnly

Trust and permissions are separate concepts.

Being trusted to assume a role does not automatically grant AWS permissions.

---

## Managed Node Group

An EKS Managed Node Group is used instead of manually managing EC2 worker nodes.

Terraform resource:

    aws_eks_node_group.main

AWS Node Group name:

    petclinic-nodes

The node group is associated with:

    EKS Cluster:
    petclinic-eks

and uses:

    Node IAM Role:
    petclinic-eks-node-role

Worker nodes are deployed into:

    private_a
    private_b

---

## Node Scaling Configuration

The current node group uses:

    desired_size = 2
    min_size     = 2
    max_size     = 3

Therefore:

    minimum nodes: 2
    desired nodes: 2
    maximum nodes: 3

The environment starts with two worker nodes.

---

## Node Instance Type

The current worker node instance type is:

    t3.small

This is selected for the learning environment and is not considered a production sizing decision.

Production instance types should be selected based on:

- CPU requirements
- memory requirements
- workload characteristics
- network performance
- cost
- architecture requirements

---

## Networking

Worker nodes are intentionally deployed in private subnets.

Current network:

    VPC
    |
    +-- eu-central-1a
    |   |
    |   +-- private_a
    |       |
    |       +-- EKS Node
    |
    +-- eu-central-1b
        |
        +-- private_b
            |
            +-- EKS Node

Worker nodes do not require public IPv4 addresses.

For outbound Internet access they use:

    EKS Node
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

This allows nodes in private subnets to reach external services without exposing them directly to the Internet.

---

## Control Plane vs Worker Nodes

EKS separates the Kubernetes Control Plane from worker nodes.

The Control Plane is AWS-managed.

The worker nodes are EC2 instances managed through the EKS Managed Node Group.

Architecture:

    AWS
    |
    +-- EKS Control Plane
    |       |
    |       +-- Kubernetes API
    |       +-- Kubernetes control components
    |
    +-- EC2 Worker Nodes
            |
            +-- kubelet
            +-- container runtime
            +-- Kubernetes workloads

The Control Plane and worker nodes use different IAM Roles.

---

## Why Managed Node Group

Managed Node Groups were selected instead of self-managed EC2 worker nodes.

### Managed Node Group

AWS manages significant parts of the worker node lifecycle.

Advantages:

- less operational overhead
- integration with EKS
- simpler node lifecycle management
- easier initial setup

Disadvantages:

- less control than fully self-managed nodes
- AWS-specific implementation
- some node lifecycle decisions remain controlled by AWS

### Self-managed Nodes

An alternative would be to manage:

    EC2
    Launch Template
    Auto Scaling Group
    IAM Instance Profile
    bootstrap configuration
    node lifecycle

This provides more control but increases operational responsibility.

Managed Node Groups are preferred for the current learning environment.

---

## Availability

Worker nodes are distributed across two Availability Zones:

    eu-central-1a
    eu-central-1b

This provides a basic multi-AZ worker architecture.

Current design:

    eu-central-1a
        private_a
            EKS Node


    eu-central-1b
        private_b
            EKS Node

This allows workloads to be distributed across Availability Zones.

However, the networking layer still uses a single NAT Gateway in `eu-central-1a`.

Therefore node placement is multi-AZ, but outbound Internet connectivity is not fully redundant.

---

## Security Model

The architecture separates AWS permissions by responsibility.

    EKS Control Plane
        |
        +-- EKS Cluster Role


    Worker Node
        |
        +-- EKS Node Role

The same IAM Role is not shared between the control plane and worker nodes.

The current configuration intentionally uses AWS managed policies to simplify the initial EKS implementation.

Least-privilege refinement can be performed later when the required AWS API actions are better understood.

---

## Alternatives Considered

### EC2 Worker Nodes with Public IPs

Rejected.

Worker nodes should remain in private subnets and should not require direct Internet exposure.

### Single Availability Zone

Rejected.

EKS worker nodes should be distributed across multiple Availability Zones to provide better failure isolation.

### Self-managed Worker Nodes

Rejected for the initial implementation.

They provide more control but introduce additional operational complexity.

Managed Node Groups are sufficient for the current learning environment.

### Shared IAM Role for Control Plane and Nodes

Rejected.

The control plane and worker nodes have different responsibilities and therefore require different IAM permissions.

Separate roles provide better isolation and follow the principle of least privilege.

---

## Consequences

### Positive

- EKS provides a managed Kubernetes Control Plane.
- Worker nodes are managed through EKS Managed Node Groups.
- Control Plane and worker nodes use separate IAM Roles.
- Worker nodes are deployed in private subnets.
- Worker nodes span two Availability Zones.
- Nodes can access the Internet through the existing NAT Gateway.
- The infrastructure is fully managed through Terraform.
- The architecture is suitable as a foundation for future Kubernetes workloads.

### Negative

- EKS and EC2 introduce AWS costs.
- Managed Node Groups provide less control than fully self-managed nodes.
- Worker nodes depend on the existing NAT Gateway for outbound Internet access.
- The current NAT architecture is not fully redundant.
- AWS managed IAM policies may provide broader permissions than a fully customized least-privilege model.

---

## Validation

The EKS Control Plane was successfully created.

The Managed Node Group was successfully created.

The worker nodes are deployed in private subnets.

The Kubernetes cluster can be accessed using:

    aws eks update-kubeconfig

Kubernetes node availability is validated using:

    kubectl get nodes

Expected state:

    EKS Cluster
        |
        +-- Control Plane
        |
        +-- Node Group
            |
            +-- Node   Ready
            |
            +-- Node   Ready

AWS infrastructure can also be inspected using:

    aws eks describe-cluster

    aws eks describe-nodegroup

Terraform state can be inspected using:

    terraform state list

---

## Current Architecture

    AWS Account
    |
    +-- IAM
    |   |
    |   +-- EKS Cluster Role
    |   |     |
    |   |     +-- Trust: eks.amazonaws.com
    |   |     +-- AmazonEKSClusterPolicy
    |   |
    |   +-- EKS Node Role
    |         |
    |         +-- Trust: ec2.amazonaws.com
    |         +-- AmazonEKSWorkerNodePolicy
    |         +-- AmazonEC2ContainerRegistryPullOnly
    |
    +-- VPC
        |
        +-- public_a
        |
        +-- public_b
        |
        +-- private_a
        |     |
        |     +-- EKS Node
        |
        +-- private_b
              |
              +-- EKS Node

        |
        +-- NAT Gateway
        |
        +-- Internet Gateway


    EKS
    |
    +-- Control Plane
    |
    +-- Managed Node Group
          |
          +-- EC2 Node
          |
          +-- EC2 Node

---

## Next Steps

The next stage is to understand and implement Kubernetes workloads on EKS.

Before deploying the application, the following topics should be investigated:

- how EKS nodes register with the Control Plane
- how kubelet communicates with the Kubernetes API
- how Kubernetes scheduling works
- how Pods are placed on worker nodes
- EKS networking and the AWS VPC CNI
- Kubernetes Service Accounts
- IAM access from Pods
- EKS Pod Identity

After the Kubernetes fundamentals are validated, the existing local GitOps architecture can be migrated towards EKS.

---

## Summary

The AWS environment now contains a functional EKS cluster with managed worker nodes.

The architecture separates responsibilities:

    EKS Control Plane
        |
        +-- Cluster IAM Role


    EKS Worker Node
        |
        +-- Node IAM Role

Worker nodes run in private subnets across two Availability Zones.

The current platform provides the foundation for running Kubernetes workloads on AWS while keeping infrastructure provisioning reproducible through Terraform.
