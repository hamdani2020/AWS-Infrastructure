module "vpc" {
  source              = "./modules/vpc"
  cidr_block          = var.vpc_cidr
  availability_zones  = ["eu-west-1a", "eu-west-1b"]
  public_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24"]
}

module "security_group" {
  source              = "./modules/security_group"
  vpc_id              = module.vpc.vpc_id
  ingress_cidr_blocks = ["0.0.0.0/0"]
}

resource "aws_internet_gateway" "igw" {
  vpc_id = module.vpc.vpc_id
}

resource "aws_route_table" "public_rt" {
  vpc_id = module.vpc.vpc_id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "public_rt_assoc" {
  count          = length(module.vpc.public_subnet_ids)
  subnet_id      = module.vpc.public_subnet_ids[count.index]
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_iam_role" "eks_cluster_role" {
  name = "eks-cluster-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "eks.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  role       = aws_iam_role.eks_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role" "eks_node_group_role" {
  name = "eks-node-group-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "ec2.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
  role       = aws_iam_role.eks_node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  role       = aws_iam_role.eks_node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "ecr_read_policy" {
  role       = aws_iam_role.eks_node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# Tag subnets for EKS
resource "aws_ec2_tag" "subnet_cluster_tag" {
  count       = length(module.vpc.public_subnet_ids)
  resource_id = module.vpc.public_subnet_ids[count.index]
  key         = "kubernetes.io/cluster/my-eks-cluster"
  value       = "shared"
}

resource "aws_ec2_tag" "subnet_elb_tag" {
  count       = length(module.vpc.public_subnet_ids)
  resource_id = module.vpc.public_subnet_ids[count.index]
  key         = "kubernetes.io/role/elb"
  value       = "1"
}

# EKS Cluster
resource "aws_eks_cluster" "eks" {
  name     = "my-eks-cluster"
  role_arn = aws_iam_role.eks_cluster_role.arn

  vpc_config {
    subnet_ids              = module.vpc.public_subnet_ids
    endpoint_private_access = false
    endpoint_public_access  = true
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy,
    aws_route_table_association.public_rt_assoc
  ]
}

# EKS Node Group
resource "aws_eks_node_group" "node_group" {
  cluster_name    = aws_eks_cluster.eks.name
  node_group_name = "default"
  node_role_arn   = aws_iam_role.eks_node_group_role.arn
  subnet_ids      = module.vpc.public_subnet_ids

  scaling_config {
    desired_size = 2
    max_size     = 3
    min_size     = 1
  }

  instance_types = ["t3.medium"]

  # Ensure adequate disk space
  disk_size = 20

  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.ecr_read_policy,
  ]

  # Optional: Add taints or labels if needed
  # taints {
  #   key    = "dedicated"
  #   value  = "gpuGroup"
  #   effect = "NO_SCHEDULE"
  # }
}

# resource "aws_iam_role" "eks_cluster_role" {
#   name = "eks-cluster-role"

#   assume_role_policy = jsonencode({
#     Version = "2012-10-17",
#     Statement = [{
#       Effect = "Allow",
#       Principal = {
#         Service = "eks.amazonaws.com"
#       },
#       Action = "sts:AssumeRole"
#     }]
#   })
# }

# resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
#   role       = aws_iam_role.eks_cluster_role.name
#   policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
# }

# resource "aws_iam_role" "eks_node_group_role" {
#   name = "eks-node-group-role"

#   assume_role_policy = jsonencode({
#     Version = "2012-10-17",
#     Statement = [{
#       Effect = "Allow",
#       Principal = {
#         Service = "ec2.amazonaws.com"
#       },
#       Action = "sts:AssumeRole"
#     }]
#   })
# }

# resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
#   role       = aws_iam_role.eks_node_group_role.name
#   policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
# }

# resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
#   role       = aws_iam_role.eks_node_group_role.name
#   policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
# }

# resource "aws_iam_role_policy_attachment" "ecr_read_policy" {
#   role       = aws_iam_role.eks_node_group_role.name
#   policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
# }


module "ec2_instance" {
  source             = "./modules/ec2"
  ami_id             = var.ami_id
  instance_type      = var.instance_type
  subnet_id          = module.vpc.public_subnet_ids[0]
  security_group_ids = [module.security_group.security_group_id]
  user_data          = file("scripts/docker_user_data.sh")
}

# module "eks" {
#   source          = "terraform-aws-modules/eks/aws"
#   cluster_name    = var.eks_cluster_name
#   cluster_version = var.eks_cluster_version
#   subnet_ids      = module.vpc.public_subnet_ids
#   vpc_id          = module.vpc.vpc_id
#   enable_irsa     = true

#   # cluster_role_arn    = aws_iam_role.eks_cluster_role.arn
#   # node_group_role_arn = aws_iam_role.eks_node_group_role.arn

#   eks_managed_node_groups = {
#     default = {
#       desired_capacity             = 2
#       max_capacity                 = 3
#       min_capacity                 = 1
#       instance_types               = ["t3.medium"]
#       manage_aws_auth              = true
#       iam_role_additional_policies = {}
#       # iam_role_additional_policies = {
#       #   "AmazonEKS_CNI_Policy" = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
#       # }
#     }

#     # cluster_role_arn    = aws_iam_role.eks_cluster_role.arn
#     # node_group_role_arn = aws_iam_role.eks_node_group_role.arn
#   }

#   node_security_group_additional_rules = {
#     ingress_self_all = {
#       type        = "ingress"
#       from_port   = 0
#       to_port     = 0
#       protocol    = "-1"
#       self        = true
#       description = "Allow all node-to-node communication"
#     },
#     ingress_control_plane = {
#       type                     = "ingress"
#       from_port                = 443
#       to_port                  = 443
#       protocol                 = "tcp"
#       source_security_group_id = module.security_group.security_group_id
#       description              = "Allow control plane to communicate with worker nodes"
#     }
#   }
# }
