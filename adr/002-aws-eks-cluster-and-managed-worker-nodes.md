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
- Kubernetes workloads that require access to AWS APIs

The goal is to keep the responsibilities and permissions of the control plane, worker nodes, and Kubernetes workloads separate.

During the initial EKS setup, the AWS VPC CNI plugin was unable to initialize because the `aws-node` DaemonSet did not have the required AWS permissions.

The cluster was therefore configured to use EKS Pod Identity for the AWS VPC CNI plugin.

---

## Decision

Use Amazon EKS with:

- AWS-managed Kubernetes Control Plane
- EKS Managed Node Group
- dedicated IAM Role for the EKS Control Plane
- dedicated IAM Role for EKS worker nodes
- dedicated IAM Role for the AWS VPC CNI
- EKS Pod Identity for the AWS VPC CNI
- EKS Pod Identity Agent add-on
- worker nodes deployed in private subnets
- worker nodes distributed across two Availability Zones

Current architecture:

    EKS Cluster
    |
    +-- AWS-managed Control Plane
    |
    +-- EKS Pod Identity Agent
    |
    +-- Managed Node Group
        |
        +-- EC2 Node
        |
        +-- EC2 Node

The AWS VPC CNI runs as a Kubernetes DaemonSet:

    kube-system
        |
        +-- aws-node
            |
            +-- AWS VPC CNI

The `aws-node` ServiceAccount receives AWS permissions through EKS Pod Identity.

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

The Cluster IAM Role is not used by worker nodes or Kubernetes workloads.

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

The Node IAM Role is also separate from the IAM Role used by the AWS VPC CNI through EKS Pod Identity.

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

For the AWS VPC CNI:

    Trust:
    pods.eks.amazonaws.com

    Permissions:
    AmazonEKS_CNI_Policy

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

## AWS VPC CNI

EKS uses the AWS VPC CNI as the Kubernetes networking plugin.

The CNI is deployed as a DaemonSet:

    kube-system
        |
        +-- aws-node
            |
            +-- one Pod per worker node

The AWS VPC CNI is responsible for providing Kubernetes Pods with networking integrated with the AWS VPC.

It requires permissions to interact with AWS networking resources, including EC2 network interfaces.

During the initial setup, the `aws-node` Pod reported:

    MissingIAMPermissions

and specifically:

    Unauthorized operation:
    failed to call ec2:DescribeNetworkInterfaces
    due to missing permissions

As a result, the worker node reported:

    Ready=False

with:

    NetworkPluginNotReady
    cni plugin not initialized

The problem was caused by the AWS VPC CNI not having the required AWS permissions.

---

## EKS Pod Identity

EKS Pod Identity is used to provide AWS permissions directly to Kubernetes workloads without relying on the EC2 worker node IAM Role.

For the AWS VPC CNI, a dedicated IAM Role was created.

Terraform resource:

    aws_iam_role.vpc_cni

AWS Role name:

    petclinic-vpc-cni-role

The role trusts:

    pods.eks.amazonaws.com

with:

    sts:AssumeRole
    sts:TagSession

The role has:

    AmazonEKS_CNI_Policy

Mental model:

    Kubernetes Pod
        |
        | ServiceAccount
        v
    aws-node
        |
        | EKS Pod Identity
        v
    petclinic-vpc-cni-role
        |
        | AmazonEKS_CNI_Policy
        v
    AWS EC2 / VPC APIs

The worker node IAM Role is therefore not used to provide the VPC CNI with its AWS permissions.

---

## EKS Pod Identity Association

The IAM Role is associated with the `aws-node` Kubernetes ServiceAccount.

Terraform resource:

    aws_eks_pod_identity_association.vpc_cni

Configuration:

    cluster_name:
    petclinic-eks

    namespace:
    kube-system

    service_account:
    aws-node

    role:
    petclinic-vpc-cni-role

Mental model:

    EKS Cluster
        |
        +-- namespace: kube-system
                |
                +-- ServiceAccount: aws-node
                        |
                        +-- Pod Identity Association
                                |
                                v
                        petclinic-vpc-cni-role

The association tells EKS which IAM Role should be provided to Pods using the specified ServiceAccount.

---

## EKS Pod Identity Agent

EKS Pod Identity requires the EKS Pod Identity Agent to be available on the worker nodes.

The agent is installed as an EKS managed add-on.

Terraform resource:

    aws_eks_addon.pod_identity_agent

Configuration:

    addon_name = "eks-pod-identity-agent"

The value:

    eks-pod-identity-agent

is the AWS-defined name of the EKS add-on.

Terraform does not infer which add-on to install.

The `addon_name` explicitly identifies the AWS-managed EKS add-on that should be installed.

Architecture:

    Kubernetes Pod
        |
        | ServiceAccount
        v
    EKS Pod Identity
        |
        v
    Pod Identity Agent
        |
        v
    IAM Role
        |
        v
    AWS APIs

The Pod Identity Agent is therefore a required infrastructure component for the Pod Identity mechanism used by the `aws-node` Pod.

---

## Why the Pod Identity Agent Was Not Present Initially

The EKS cluster itself does not automatically install every available EKS add-on.

Creating an EKS cluster and Managed Node Group does not mean that optional EKS add-ons are automatically enabled.

The Pod Identity Agent therefore had to be explicitly added:

    resource "aws_eks_addon" "pod_identity_agent" {
      cluster_name = aws_eks_cluster.main.name
      addon_name   = "eks-pod-identity-agent"
    }

This makes the dependency explicit and keeps the infrastructure reproducible through Terraform.

---

## AWS VPC CNI IAM Configuration

The final configuration contains a dedicated IAM Role:

    petclinic-vpc-cni-role

with:

    Trust:
    pods.eks.amazonaws.com

and:

    Permission:
    AmazonEKS_CNI_Policy

The Pod Identity Association connects this role with:

    kube-system/aws-node

The architecture is:

    aws-node Pod
        |
        | ServiceAccount: aws-node
        v
    EKS Pod Identity Association
        |
        v
    petclinic-vpc-cni-role
        |
        +-- AmazonEKS_CNI_Policy
        |
        v
    AWS EC2 / VPC APIs

---

## Control Plane vs Worker Nodes vs Pod IAM

The architecture now separates three different levels of AWS permissions.

### EKS Control Plane

    EKS Control Plane
            |
            v
    petclinic-eks-cluster-role
            |
            v
    AmazonEKSClusterPolicy

### EC2 Worker Nodes

    EC2 Worker Node
            |
            v
    petclinic-eks-node-role
            |
            +-- AmazonEKSWorkerNodePolicy
            +-- AmazonEC2ContainerRegistryPullOnly

### Kubernetes Pod

    aws-node Pod
            |
            v
    EKS Pod Identity
            |
            v
    petclinic-vpc-cni-role
            |
            v
    AmazonEKS_CNI_Policy

This avoids using the node IAM Role as a general-purpose identity for Kubernetes workloads.

---

## Why Not Give the CNI Permissions Through the Node Role

An alternative would be to attach:

    AmazonEKS_CNI_Policy

directly to:

    petclinic-eks-node-role

This was not selected.

The reason is separation of responsibilities.

The EC2 Node IAM Role represents the worker node.

The AWS VPC CNI is a Kubernetes workload running on that node.

Using EKS Pod Identity allows the CNI to receive its permissions through its Kubernetes ServiceAccount instead of granting additional AWS permissions to every worker node.

This provides a cleaner IAM model and better separation of permissions.

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


    Kubernetes Pod
        |
        +-- Pod Identity Role

The same IAM Role is not shared between the control plane, worker nodes, and the AWS VPC CNI.

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

### AWS VPC CNI Permissions Through Node IAM Role

Rejected.

Attaching `AmazonEKS_CNI_Policy` directly to the worker node role would give every worker node the CNI permissions.

Instead, EKS Pod Identity is used so that the `aws-node` Pod receives a dedicated IAM Role.

### IAM Roles for Service Accounts (IRSA)

Considered but not selected for the current implementation.

EKS Pod Identity provides a simpler mechanism for associating IAM Roles with Kubernetes ServiceAccounts without requiring the same OIDC provider configuration used by IRSA.

---

## Consequences

### Positive

- EKS provides a managed Kubernetes Control Plane.
- Worker nodes are managed through EKS Managed Node Groups.
- Control Plane and worker nodes use separate IAM Roles.
- Worker nodes are deployed in private subnets.
- Worker nodes span two Availability Zones.
- Nodes can access the Internet through the existing NAT Gateway.
- AWS VPC CNI has its own dedicated IAM Role.
- Kubernetes Pods can receive AWS permissions through EKS Pod Identity.
- The EKS Pod Identity Agent is managed as an EKS add-on.
- The node IAM Role does not need to contain the VPC CNI permissions.
- The infrastructure is fully managed through Terraform.
- The architecture provides a clean foundation for future Kubernetes workloads requiring AWS API access.

### Negative

- EKS and EC2 introduce AWS costs.
- Managed Node Groups provide less control than fully self-managed nodes.
- Worker nodes depend on the existing NAT Gateway for outbound Internet access.
- The current NAT architecture is not fully redundant.
- AWS managed IAM policies may provide broader permissions than a fully customized least-privilege model.
- EKS Pod Identity introduces an additional component: the Pod Identity Agent.

---

## Problem Encountered During Implementation

The initial worker nodes were created successfully but remained:

    NotReady

The node reported:

    NetworkPluginNotReady

and:

    cni plugin not initialized

Inspection of the `aws-node` Pod showed:

    MissingIAMPermissions

with:

    Unauthorized operation:
    failed to call ec2:DescribeNetworkInterfaces
    due to missing permissions

The AWS VPC CNI container repeatedly failed its health probes:

    timeout: failed to connect service ":50051" within 5s

The root cause was that the AWS VPC CNI did not have the required IAM permissions.

The following components were then introduced:

    EKS Pod Identity Agent
            |
            v
    EKS Pod Identity Association
            |
            v
    petclinic-vpc-cni-role
            |
            v
    AmazonEKS_CNI_Policy

After the configuration was applied and the `aws-node` Pods restarted, the CNI successfully initialized and the worker node transitioned to:

    Ready

---

## Validation

The EKS Control Plane was successfully created.

The Managed Node Group was successfully created.

The worker nodes are deployed in private subnets.

The Kubernetes cluster can be accessed using:

    aws eks update-kubeconfig

Kubernetes node availability is validated using:

    kubectl get nodes -o wide

Expected state:

    NAME                                           STATUS   ROLES    AGE
    ip-10-0-10-xxx.eu-central-1.compute.internal  Ready    <none>   ...
    ip-10-0-11-xxx.eu-central-1.compute.internal  Ready    <none>   ...

The AWS VPC CNI can be inspected using:

    kubectl get pods -n kube-system -l k8s-app=aws-node

The Pod Identity Agent can be inspected using:

    kubectl get pods -n kube-system

The Pod Identity association can be inspected using:

    aws eks list-pod-identity-associations \
      --cluster-name petclinic-eks \
      --region eu-central-1

The association can be inspected using:

    aws eks describe-pod-identity-association \
      --cluster-name petclinic-eks \
      --association-id <association-id> \
      --region eu-central-1

The IAM policies attached to the VPC CNI role can be inspected using:

    aws iam list-attached-role-policies \
      --role-name petclinic-vpc-cni-role

The IAM trust policy can be inspected using:

    aws iam get-role \
      --role-name petclinic-vpc-cni-role \
      --query 'Role.AssumeRolePolicyDocument'

The AWS VPC CNI logs can be inspected using:

    kubectl logs <aws-node-pod> -n kube-system -c aws-node

The final result is:

    EKS Cluster
        |
        +-- Control Plane
        |
        +-- Managed Node Group
              |
              +-- Node   Ready
              |
              +-- Node   Ready

The worker nodes are now ready to run Kubernetes workloads.

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
    |   |     |
    |   |     +-- Trust: ec2.amazonaws.com
    |   |     +-- AmazonEKSWorkerNodePolicy
    |   |     +-- AmazonEC2ContainerRegistryPullOnly
    |   |
    |   +-- VPC CNI Role
    |         |
    |         +-- Trust: pods.eks.amazonaws.com
    |         +-- AmazonEKS_CNI_Policy
    |
    +-- VPC
    |   |
    |   +-- public_a
    |   |
    |   +-- public_b
    |   |
    |   +-- private_a
    |   |     |
    |   |     +-- EKS Node
    |   |
    |   +-- private_b
    |         |
    |         +-- EKS Node
    |
    +-- NAT Gateway
    |
    +-- Internet Gateway
    |
    +-- EKS
        |
        +-- Control Plane
        |
        +-- Pod Identity Agent
        |
        +-- Managed Node Group
              |
              +-- EC2 Node
              |     |
              |     +-- aws-node
              |           |
              |           +-- EKS Pod Identity
              |                 |
              |                 +-- petclinic-vpc-cni-role
              |
              +-- EC2 Node
                    |
                    +-- aws-node
                          |
                          +-- EKS Pod Identity
                                |
                                +-- petclinic-vpc-cni-role

---

## Next Steps

The next stage is to understand and implement Kubernetes workloads on EKS.

The following topics should be investigated:

- how EKS nodes register with the Control Plane
- how kubelet communicates with the Kubernetes API
- how Kubernetes scheduling works
- how Pods are placed on worker nodes
- EKS networking and the AWS VPC CNI
- Kubernetes Service Accounts
- IAM access from Pods
- EKS Pod Identity
- Kubernetes Services
- Ingress and AWS Load Balancers
- application deployment on EKS
- GitOps deployment to EKS

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


    AWS VPC CNI Pod
        |
        +-- EKS Pod Identity
                |
                +-- VPC CNI IAM Role

Worker nodes run in private subnets across two Availability Zones.

The AWS VPC CNI receives its required AWS permissions through EKS Pod Identity instead of through the worker node IAM Role.

The EKS Pod Identity Agent is installed as an EKS managed add-on and enables this identity mechanism.

The worker nodes successfully transition to:

    Ready

The current platform therefore provides the foundation for running Kubernetes workloads on AWS while keeping infrastructure provisioning and IAM configuration reproducible through Terraform.
