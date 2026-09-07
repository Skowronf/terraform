# ADR-003: AWS Load Balancer Controller and EKS Pod Identity

## Status

Accepted

---

## Context

The EKS cluster needs a mechanism to create and manage AWS Elastic Load Balancers based on Kubernetes resources.

Kubernetes itself does not directly create AWS Load Balancers.

A Kubernetes controller is therefore required to:

- watch Kubernetes resources
- detect changes in their desired state
- communicate with the AWS API
- create and configure AWS Load Balancers
- configure target groups and listeners
- manage security groups associated with AWS Load Balancers
- continuously reconcile AWS resources with Kubernetes resources

The AWS Load Balancer Controller is used for this purpose.

The controller runs inside the Kubernetes cluster as a normal Kubernetes workload.

Because it needs to communicate with AWS APIs, it requires an AWS IAM identity.

The project already uses EKS Pod Identity for the AWS VPC CNI, so the same mechanism is used for the AWS Load Balancer Controller.

---

## Decision

Use the AWS Load Balancer Controller inside the EKS cluster.

The controller receives AWS permissions through:

    Kubernetes ServiceAccount
            |
            v
    EKS Pod Identity
            |
            v
    IAM Role
            |
            v
    IAM Policy
            |
            v
    AWS APIs

The controller is deployed and managed through the existing GitOps/Argo CD setup.

Terraform is responsible for:

- IAM policy
- IAM role
- IAM trust policy
- EKS Pod Identity association

Argo CD is responsible for:

- installing the Kubernetes controller
- managing its Deployment
- managing its ServiceAccount
- keeping the controller configuration synchronized

This creates a clear separation between AWS infrastructure and Kubernetes workloads.

---

## AWS Load Balancer Controller

The AWS Load Balancer Controller is a Kubernetes controller that integrates Kubernetes with AWS Elastic Load Balancing.

It watches Kubernetes resources such as:

    Ingress
    Service
    TargetGroupBinding

and reconciles them with AWS resources.

Conceptually:

    Kubernetes Resource
            |
            v
    AWS Load Balancer Controller
            |
            v
        AWS API
            |
            v
    AWS Load Balancer

The controller does not replace Kubernetes Ingress.

Instead, it provides the AWS integration required to turn Kubernetes networking resources into AWS load-balancing infrastructure.

---

## Controller Responsibility

The controller follows the Kubernetes reconciliation model.

The basic process is:

    Desired State
        |
        v
    Kubernetes Resource
        |
        v
    Controller observes resource
        |
        v
    Compare desired vs actual state
        |
        v
    AWS API calls
        |
        v
    AWS Resources
        |
        v
    Actual State

If the actual state differs from the desired state, the controller attempts to correct it.

For example:

    Kubernetes Ingress
            |
            | desired state
            v
    AWS Load Balancer Controller
            |
            | create/update
            v
    AWS Load Balancer

If the Load Balancer is modified or removed outside Kubernetes, the controller can detect the difference and reconcile the infrastructure.

---

## Why the Controller Needs AWS IAM

The AWS Load Balancer Controller runs inside Kubernetes, but it needs to manage AWS resources.

For example, it may need to perform actions such as:

    CreateLoadBalancer
    CreateTargetGroup
    CreateListener
    CreateRule
    RegisterTargets
    ModifyLoadBalancerAttributes
    DeleteLoadBalancer

It also needs read permissions to discover the AWS environment:

    DescribeVpcs
    DescribeSubnets
    DescribeSecurityGroups
    DescribeInstances
    DescribeLoadBalancers
    DescribeTargetGroups

Therefore the controller requires permissions to communicate with AWS APIs.

---

## IAM Architecture

A dedicated IAM Role is created for the controller.

Terraform resource:

    aws_iam_role.aws_load_balancer_controller

AWS Role name:

    petclinic-aws-load-balancer-controller

The role trusts:

    pods.eks.amazonaws.com

The role therefore allows EKS Pod Identity to provide this identity to the Kubernetes workload.

Mental model:

    AWS Load Balancer Controller Pod
            |
            | ServiceAccount
            v
    EKS Pod Identity
            |
            v
    petclinic-aws-load-balancer-controller
            |
            v
    AWS IAM Policy
            |
            v
    AWS APIs

---

## IAM Policy

A dedicated IAM Policy is created for the controller.

Terraform resource:

    aws_iam_policy.aws_load_balancer_controller

The policy contains the AWS API permissions required by the AWS Load Balancer Controller.

The policy covers resources including:

    EC2
    Elastic Load Balancing
    IAM
    ACM
    WAF
    Shield
    Cognito

The policy also contains conditions based on AWS resource tags.

For example:

    elbv2.k8s.aws/cluster

This allows the controller to manage resources associated with the Kubernetes cluster while reducing the risk of accidentally modifying unrelated AWS resources.

---

## IAM Policy Source

The current IAM policy is stored as a local JSON file:

    aws-load-balancer-controller.json

Terraform loads the policy using:

    file("${path.module}/aws-load-balancer-controller.json")

The policy is version-controlled together with the Terraform configuration.

Terraform is responsible for creating the AWS IAM Policy from this definition.

The JSON file represents the permissions.

The Terraform IAM Role represents the identity.

The Pod Identity Association connects that identity to the Kubernetes ServiceAccount.

---

## IAM Role Attachment

The policy is attached to the dedicated controller IAM Role.

Terraform resource:

    aws_iam_role_policy_attachment.aws_load_balancer_controller

Architecture:

    IAM Role
        |
        +-- petclinic-aws-load-balancer-controller
                |
                +-- AWS Load Balancer Controller Policy

The controller therefore does not use the worker node IAM Role.

---

## EKS Pod Identity

EKS Pod Identity is used to provide the controller with AWS credentials.

The controller uses the Kubernetes ServiceAccount:

    aws-load-balancer-controller

The Pod Identity Association connects:

    cluster:
    petclinic-eks

    namespace:
    kube-system

    service account:
    aws-load-balancer-controller

with:

    IAM Role:
    petclinic-aws-load-balancer-controller

Terraform resource:

    aws_eks_pod_identity_association.aws_load_balancer_controller

Mental model:

    kube-system
        |
        +-- aws-load-balancer-controller
                |
                | ServiceAccount
                v
        EKS Pod Identity
                |
                v
        petclinic-aws-load-balancer-controller
                |
                v
        AWS Load Balancer APIs

---

## Why Not Use the Node IAM Role

The controller is a Kubernetes workload.

It should therefore not receive AWS permissions through the EC2 worker node IAM Role.

An alternative would be:

    EC2 Node
        |
        v
    Node IAM Role
        |
        +-- Load Balancer permissions

This was rejected.

It would mean that every workload running on the node could potentially inherit or use permissions intended specifically for the Load Balancer Controller.

Instead:

    Controller Pod
        |
        v
    ServiceAccount
        |
        v
    Pod Identity
        |
        v
    Dedicated IAM Role

This provides better separation of responsibilities and follows the principle of least privilege.

---

## Kubernetes Deployment

The AWS Load Balancer Controller is installed into:

    namespace:
    kube-system

The controller runs as a Kubernetes Deployment.

Example architecture:

    kube-system
        |
        +-- aws-load-balancer-controller
                |
                +-- Pod
                |
                +-- ServiceAccount
                        |
                        +-- EKS Pod Identity
                                |
                                +-- IAM Role

The controller is managed by Argo CD as part of the GitOps platform.

Terraform does not manage the Kubernetes Deployment itself.

---

## GitOps Responsibility

The project already uses Argo CD to manage Kubernetes applications.

The AWS Load Balancer Controller is therefore treated as a Kubernetes platform component.

The responsibility is split as follows:

    Terraform
        |
        +-- AWS VPC
        +-- EKS
        +-- IAM
        +-- Pod Identity Association


    Argo CD
        |
        +-- AWS Load Balancer Controller
        +-- Kubernetes configuration
        +-- ServiceAccount
        +-- Deployment

This avoids mixing AWS infrastructure management with Kubernetes application management.

---

## Controller vs NGINX Ingress

The AWS Load Balancer Controller and ingress-nginx have different responsibilities.

The intended architecture is:

    Internet
        |
        v
    AWS Load Balancer
        |
        v
    ingress-nginx
        |
        v
    Kubernetes Service
        |
        v
    Application Pod

The AWS Load Balancer Controller is responsible for the AWS-facing layer.

The ingress-nginx controller is responsible for the Kubernetes HTTP routing layer.

Conceptually:

    AWS Load Balancer Controller
            |
            | AWS layer
            v
        AWS ALB/NLB
            |
            v
        ingress-nginx
            |
            | Kubernetes layer
            v
        Services
            |
            v
        Pods

The two controllers therefore solve different problems.

---

## Current ingress-nginx Configuration

The existing ingress-nginx deployment uses:

    kind: Deployment

with:

    replicaCount: 2

and:

    service:
      type: ClusterIP

This means ingress-nginx is not directly exposed to the Internet through a Kubernetes LoadBalancer Service.

Instead, the intended architecture is for an AWS Load Balancer to provide the external entry point.

The AWS Load Balancer Controller will manage that AWS-facing resource.

---

## Kubernetes Ingress

The application already contains a Kubernetes Ingress:

    apiVersion: networking.k8s.io/v1
    kind: Ingress

with:

    ingressClassName: nginx

This means the Ingress is currently intended to be handled by ingress-nginx.

The AWS Load Balancer Controller does not automatically mean that this Ingress will be managed by AWS.

The `ingressClassName` determines which controller should process the resource.

Therefore the current application routing model remains:

    Ingress
        |
        | ingressClassName: nginx
        v
    ingress-nginx

The AWS Load Balancer Controller will provide the AWS-facing integration required by the final architecture.

---

## Controller Startup Validation

The controller successfully started inside the EKS cluster.

The observed controller version is:

    v2.14.0

The controller successfully initialized:

    health check
    readiness check
    webhook server
    metrics server
    certificate watcher
    leader election

The controller reached:

    attempting to acquire leader lease

This indicates that the controller process successfully started and entered its normal Kubernetes controller lifecycle.

---

## Leader Election

The controller uses Kubernetes leader election.

The purpose is to ensure that only one controller replica actively performs reconciliation at a time when multiple replicas are running.

Conceptually:

    Controller Pod A
          |
          +-- leader


    Controller Pod B
          |
          +-- standby

If the active leader fails, another replica can acquire the lease.

This allows the controller deployment to be made highly available.

---

## Why the Controller Is Not Yet Creating a Load Balancer

Installing the AWS Load Balancer Controller does not automatically create an AWS Load Balancer.

The controller waits for Kubernetes resources that require AWS load-balancing functionality.

The process is:

    Controller installed
            |
            v
    Controller watches Kubernetes API
            |
            v
    Kubernetes Service / Ingress created
            |
            v
    Controller reconciles resource
            |
            v
    AWS API
            |
            v
    AWS Load Balancer

Therefore the controller is infrastructure that enables future AWS Load Balancer creation.

It does not create a Load Balancer simply because the controller itself exists.

---

## Application Networking Architecture

The target architecture is:

    Internet
        |
        v
    AWS Load Balancer
        |
        v
    ingress-nginx
        |
        v
    Kubernetes Service
        |
        v
    Petclinic Pods
        |
        v
    PostgreSQL RDS

The AWS Load Balancer Controller manages the AWS Load Balancer.

The ingress-nginx controller manages HTTP routing inside Kubernetes.

The Petclinic application provides the actual workload.

RDS provides the database.

Each component therefore has a separate responsibility.

---

## Terraform vs Kubernetes vs GitOps

The project uses three different layers of responsibility.

### Terraform

Terraform manages AWS infrastructure and AWS identities:

    VPC
    Subnets
    NAT Gateway
    EKS
    RDS
    IAM
    EKS Pod Identity

### Kubernetes

Kubernetes manages:

    Pods
    Deployments
    Services
    Ingresses
    ServiceAccounts

### Argo CD

Argo CD manages Kubernetes resources from Git.

The architecture is therefore:

    Git
      |
      v
    Argo CD
      |
      v
    Kubernetes
      |
      v
    AWS Load Balancer Controller
      |
      v
    AWS APIs

Terraform manages the AWS infrastructure required by this platform.

---

## Alternatives Considered

### Manual AWS Load Balancer

Rejected.

Manually creating the AWS Load Balancer would duplicate information already represented by Kubernetes resources.

It would also break the Kubernetes reconciliation model.

### Terraform-managed AWS Load Balancer

Rejected for application-facing load balancing.

Terraform is responsible for infrastructure, while Kubernetes should manage resources directly related to Kubernetes workloads.

The AWS Load Balancer Controller provides the Kubernetes-to-AWS integration required for this.

### Node IAM Role

Rejected.

The controller should not receive AWS permissions through the worker node IAM Role.

A dedicated IAM Role provides better permission isolation.

### IAM Roles for Service Accounts

Considered but not selected.

EKS Pod Identity is already used by the cluster and provides the required identity mechanism without introducing an additional IRSA-specific configuration.

### Installing the Controller Manually

Rejected.

The controller is a Kubernetes platform component and should be managed through the existing GitOps workflow.

Argo CD provides version-controlled, declarative deployment and automatic reconciliation.

---

## Consequences

### Positive

- Kubernetes can request AWS Load Balancer resources declaratively.
- AWS resources can be reconciled automatically with Kubernetes desired state.
- The controller has a dedicated IAM Role.
- Worker nodes do not require Load Balancer permissions.
- AWS permissions are provided through EKS Pod Identity.
- IAM configuration remains managed by Terraform.
- Kubernetes controller deployment remains managed by Argo CD.
- The architecture separates infrastructure management from Kubernetes workload management.
- The controller can manage AWS ALBs/NLBs required by Kubernetes workloads.
- The controller supports AWS-specific integrations such as security groups, target groups, ACM, WAF and Shield.

### Negative

- The platform now depends on an additional Kubernetes controller.
- The controller requires a relatively broad IAM policy.
- AWS-specific functionality introduces some vendor coupling.
- Load Balancer behavior depends on correct Kubernetes configuration.
- The controller introduces another component that must be monitored and upgraded.
- The complete traffic path cannot be validated until the application workload is deployed.

---

## Validation

The AWS Load Balancer Controller Deployment can be checked using:

    kubectl get pods -n kube-system

The controller logs can be inspected using:

    kubectl logs \
      -n kube-system \
      deployment/aws-load-balancer-controller

The ServiceAccount can be checked using:

    kubectl get serviceaccount \
      aws-load-balancer-controller \
      -n kube-system

The Pod Identity associations can be checked using:

    aws eks list-pod-identity-associations \
      --cluster-name petclinic-eks \
      --region eu-central-1

The IAM Role can be checked using:

    aws iam get-role \
      --role-name petclinic-aws-load-balancer-controller

The attached policy can be checked using:

    aws iam list-attached-role-policies \
      --role-name petclinic-aws-load-balancer-controller

The controller should be running successfully before deploying Kubernetes resources that depend on AWS Load Balancing.

---

## Current State

The following components are now implemented:

    AWS VPC
        |
        +-- Public Subnets
        +-- Private Subnets
        +-- NAT Gateway
        +-- Internet Gateway
        |
        v
    EKS
        |
        +-- Managed Worker Nodes
        |
        +-- Pod Identity Agent
        |
        +-- AWS VPC CNI
        |       |
        |       +-- Pod Identity
        |              |
        |              +-- VPC CNI IAM Role
        |
        +-- AWS Load Balancer Controller
                |
                +-- ServiceAccount
                |
                +-- Pod Identity
                       |
                       +-- Load Balancer IAM Role
                              |
                              +-- Load Balancer IAM Policy

The AWS Load Balancer Controller is successfully running in the cluster.

The controller has the required AWS identity through EKS Pod Identity.

The controller is ready to react to Kubernetes resources that require AWS Load Balancer functionality.

---

## Next Steps

The next stage is to deploy the Petclinic application to EKS.

The application deployment should establish:

    Petclinic Deployment
        |
        v
    Petclinic Pods
        |
        v
    Kubernetes Service
        |
        v
    PostgreSQL RDS

After the application is running and can communicate with RDS, the external traffic path can be configured and validated:

    Internet
        |
        v
    AWS Load Balancer
        |
        v
    ingress-nginx
        |
        v
    Petclinic Service
        |
        v
    Petclinic Pods
        |
        v
    PostgreSQL RDS

This will allow the complete AWS application path to be validated.

---

## Summary

The AWS Load Balancer Controller has been introduced as the Kubernetes-to-AWS integration layer for load balancing.

The controller runs inside EKS and observes Kubernetes resources.

It uses:

    ServiceAccount
        |
        v
    EKS Pod Identity
        |
        v
    Dedicated IAM Role
        |
        v
    AWS Load Balancer Controller IAM Policy
        |
        v
    AWS APIs

Terraform manages the AWS-side identity and permissions.

Argo CD manages the Kubernetes-side controller deployment.

The worker node IAM Role is not used by the controller.

The controller is now ready to react to Kubernetes resources that require AWS Load Balancer functionality.

The actual AWS Load Balancer will be created only when an appropriate Kubernetes resource is deployed and configured to be handled by the AWS Load Balancer Controller.
