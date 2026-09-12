module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~>21.0"

  name               = "openai-chatbot-eks"
  kubernetes_version = "1.35"

  endpoint_public_access  = true
  endpoint_private_access = true

  endpoint_public_access_cidrs = ["182.189.94.218/32"]

  enable_cluster_creator_admin_permissions = true

  authentication_mode = "API_AND_CONFIG_MAP"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  eks_managed_node_groups = {
    default = {
      instance_types = ["t3.small"]

      min_size     = 2
      max_size     = 3
      desired_size = 2

      capacity_type = "SPOT"

      subnet_ids = module.vpc.private_subnets
    }
  }

  addons = {
    coredns = {
      before_compute = true
    }

    kube-proxy = {
      before_compute = true
    }

    vpc-cni = {
      before_compute = true
    }

    eks-pod-identity-agent = {
      before_compute = true
    }
  }

}
