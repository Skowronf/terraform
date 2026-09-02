# cilium-values.yaml
#
# EKS + AWS VPC CNI + Cilium CNI chaining
#
# AWS VPC CNI remains responsible for:
# - pod networking
# - VPC integration
# - IPAM
#
# Cilium provides:
# - eBPF datapath
# - NetworkPolicy enforcement
# - network visibility

cni:
  chainingMode: aws-cni
  exclusive: false

routingMode: native

enableIPv4Masquerade: false

kubeProxyReplacement: false
