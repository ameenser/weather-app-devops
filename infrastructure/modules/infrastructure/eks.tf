# -----------------------------
# EKS Cluster IAM Role
# -----------------------------
resource "aws_iam_role" "eks_cluster_role" {
  name = "${var.project_name}-eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-eks-cluster-role"
  }
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  role       = aws_iam_role.eks_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# -----------------------------
# EKS Cluster
# -----------------------------
resource "aws_eks_cluster" "main" {
  name     = var.eks_cluster_name
  role_arn = aws_iam_role.eks_cluster_role.arn
  version  = var.eks_cluster_version

  vpc_config {
    subnet_ids = [
      aws_subnet.private_1.id,
      aws_subnet.private_2.id
    ]

    endpoint_private_access = true
    endpoint_public_access  = true

    # For lab you can keep public access.
    # Later we can restrict it to your IP.
  }

  access_config {
    authentication_mode                         = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = true
  }

  tags = {
    Name                                   = var.eks_cluster_name
    "alpha.eksctl.io/cluster-oidc-enabled" = "true"

  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy
  ]
}

# -----------------------------
# EKS Worker Nodes IAM Role
# -----------------------------
resource "aws_iam_role" "eks_node_role" {
  name = "${var.project_name}-eks-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-eks-node-role"
  }
}

resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "eks_ecr_readonly_policy" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# -----------------------------
# EKS Managed Node Group
# -----------------------------
resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = var.eks_node_group_name
  node_role_arn   = aws_iam_role.eks_node_role.arn
  subnet_ids = [
    aws_subnet.private_1.id,
    aws_subnet.private_2.id
  ]

  instance_types = var.eks_node_instance_types
  capacity_type  = "ON_DEMAND"

  scaling_config {
    desired_size = var.eks_node_desired_size
    min_size     = var.eks_node_min_size
    max_size     = var.eks_node_max_size
  }

  update_config {
    max_unavailable = 1
  }

  labels = {
    role = "worker"
    app  = "weather-app"
  }

  tags = {
    Name = "${var.project_name}-eks-node-group"
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.eks_ecr_readonly_policy
  ]
}
