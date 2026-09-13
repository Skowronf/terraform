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

The application will not use ingress-nginx. The AWS Load Balancer Controller will provide the external load-balancing and HTTP/HTTPS ingress functionality directly through AWS Application Load Balancers.

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

The controller provides the AWS integration required to turn Kubernetes networking resources into AWS load-balancing infrastructure.

For HTTP/HTTPS traffic, Kubernetes Ingress resources can be handled directly by the AWS Load Balancer Controller and mapped to an AWS Application Load Balancer.

For service-level load balancing, Kubernetes Services of type `LoadBalancer` can be used to provision AWS load-balancing resources.

No additional ingress controller such as ingress-nginx is required.

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
    AWS Application Load Balancer

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

It would mean that workloads running on the node could potentially inherit or use permissions intended specifically for the Load Balancer Controller.

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

## AWS Load Balancer Controller as the Ingress Layer

The project does not use ingress-nginx.

The AWS Load Balancer Controller provides the external ingress functionality directly through AWS Application Load Balancer.

The intended architecture is:

    Internet
        |
        v
    AWS Application Load Balancer
        |
        v
    Kubernetes Service
        |
        v
    Petclinic Pods

For HTTP/HTTPS traffic, the Kubernetes Ingress resource defines the desired routing configuration.

The AWS Load Balancer Controller observes the Ingress and creates or updates the corresponding AWS Application Load Balancer resources.

Conceptually:

    Kubernetes Ingress
            |
            v
    AWS Load Balancer Controller
            |
            v
    AWS Application Load Balancer
            |
            v
    Kubernetes Service
            |
            v
    Petclinic Pods

There is no intermediate NGINX controller.

This reduces the number of components in the request path and removes the need to maintain a separate Kubernetes HTTP ingress controller.

---

## Kubernetes Ingress

The application can use a Kubernetes Ingress handled directly by the AWS Load Balancer Controller.

The Ingress should use:

    ingressClassName: alb

This explicitly identifies the AWS Load Balancer Controller as the controller responsible for the resource.

Example:

    apiVersion: networking.k8s.io/v1
    kind: Ingress
    metadata:
      name: petclinic
      namespace: petclinic
    spec:
      ingressClassName: alb

The AWS Load Balancer Controller then reconciles the Ingress with an AWS Application Load Balancer.

Conceptually:

    Ingress
        |
        | ingressClassName: alb
        v
    AWS Load Balancer Controller
        |
        v
    AWS Application Load Balancer
        |
        v
    Kubernetes Service
        |
        v
    Petclinic Pods

---

## Application Networking Architecture

The target architecture is:

    Internet
        |
        v
    AWS Application Load Balancer
        |
        v
    Kubernetes Service
        |
        v
    Petclinic Pods
        |
        v
    PostgreSQL RDS

The AWS Load Balancer Controller manages the AWS Application Load Balancer.

The Kubernetes Service provides the internal application endpoint.

The Petclinic application provides the actual workload.

RDS provides the database.

Each component therefore has a separate responsibility.

---

## Load Balancer Targeting

The AWS Load Balancer Controller can integrate the AWS Application Load Balancer directly with Kubernetes workloads.

The exact target configuration depends on the selected controller configuration and annotations.

The important architectural principle is that the AWS Load Balancer is managed from Kubernetes declarative resources rather than being manually created.

Conceptually:

    Kubernetes Ingress
            |
            v
    AWS Load Balancer Controller
            |
            v
    ALB Listener / Rules
            |
            v
    Target Group
            |
            v
    Kubernetes Application

This allows the Kubernetes resource to remain the source of truth for the desired application-facing load-balancing configuration.

---

## Why Not Use ingress-nginx

ingress-nginx was considered as a separate Kubernetes HTTP ingress layer but is not required for the selected architecture.

Using ingress-nginx would introduce an additional component:

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

This would require:

- an additional Kubernetes controller
- an additional Deployment
- an additional Service
- additional configuration
- additional monitoring and upgrades
- an additional network hop

The selected architecture removes this layer:

    Internet
        |
        v
    AWS Application Load Balancer
        |
        v
    Kubernetes Service
        |
        v
    Petclinic Pods

The AWS Load Balancer Controller already provides the required AWS integration and can handle Kubernetes Ingress resources directly.

Therefore ingress-nginx is not part of the target architecture.

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
    Kubernetes Ingress created
            |
            v
    Controller reconciles resource
            |
            v
    AWS API
            |
            v
    AWS Application Load Balancer

Therefore the controller is infrastructure that enables future AWS Load Balancer creation.

It does not create a Load Balancer simply because the controller itself exists.

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

### ingress-nginx

Rejected.

A separate NGINX ingress controller is unnecessary because the AWS Load Balancer Controller can handle Kubernetes Ingress resources directly and provision an AWS Application Load Balancer.

Removing ingress-nginx simplifies the architecture and reduces the number of components involved in the external traffic path.

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
- Kubernetes Ingress resources can be handled directly by the AWS Load Balancer Controller.
- No additional ingress controller is required.
- The external traffic path contains fewer components.
- The architecture avoids maintaining a separate NGINX deployment and configuration.
- The controller supports AWS-specific integrations such as security groups, target groups, ACM, WAF and Shield.

### Negative

- The platform depends on the AWS Load Balancer Controller.
- The controller requires a relatively broad IAM policy.
- AWS-specific functionality introduces some vendor coupling.
- Load Balancer behavior depends on correct Kubernetes configuration and controller annotations.
- The controller introduces another component that must be monitored and upgraded.
- The complete traffic path cannot be validated until the application workload and Ingress are deployed.

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

The Kubernetes Ingress can be checked using:

    kubectl get ingress -A

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

No ingress-nginx controller is part of the target architecture.

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

After the application is running and can communicate with RDS, the external traffic path can be configured and validated using a Kubernetes Ingress:

    Internet
        |
        v
    AWS Application Load Balancer
        |
        v
    Kubernetes Service
        |
        v
    Petclinic Pods
        |
        v
    PostgreSQL RDS

The Ingress should be configured with:

    ingressClassName: alb

This will allow the AWS Load Balancer Controller to create and manage the corresponding AWS Application Load Balancer.

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

The target application architecture does not use ingress-nginx.

Instead, Kubernetes Ingress resources are handled directly by the AWS Load Balancer Controller, which provisions and manages the AWS Application Load Balancer.

The actual AWS Load Balancer will be created only when an appropriate Kubernetes resource is deployed and configured to be handled by the AWS Load Balancer Controller.
