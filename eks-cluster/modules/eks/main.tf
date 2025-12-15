locals {
  cluster_name = var.cluster_name
}

# -------- Security groups --------

resource "aws_security_group" "cluster" {
  name        = "${local.cluster_name}-cluster-sg"
  description = "EKS control plane"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${local.cluster_name}-cluster-sg" }
}

resource "aws_security_group" "nodes" {
  name        = "${local.cluster_name}-nodes-sg"
  description = "EKS nodes"
  vpc_id      = var.vpc_id

  # allow all from same SG (node <-> node)
  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${local.cluster_name}-nodes-sg" }
}

resource "aws_security_group" "alb" {
  name        = "${local.cluster_name}-alb-sg"
  description = "Ingress ALB"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${local.cluster_name}-alb-sg" }
}

# -------- KMS + logs --------

resource "aws_kms_key" "eks" {
  description         = "KMS key for EKS secrets"
  enable_key_rotation = true
}

resource "aws_cloudwatch_log_group" "eks" {
  name              = "/aws/eks/${local.cluster_name}/cluster"
  retention_in_days = 30
}

# -------- EKS cluster IAM --------

resource "aws_iam_role" "eks_cluster" {
  name = "${local.cluster_name}-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Principal = { Service = "eks.amazonaws.com" }
      Effect    = "Allow"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_cluster_AmazonEKSClusterPolicy" {
  role       = aws_iam_role.eks_cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role_policy_attachment" "eks_cluster_AmazonEKSServicePolicy" {
  role       = aws_iam_role.eks_cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
}

# -------- EKS cluster --------

resource "aws_eks_cluster" "this" {
  name     = local.cluster_name
  role_arn = aws_iam_role.eks_cluster.arn
  version  = var.cluster_version

  vpc_config {
    subnet_ids              = concat(var.private_subnet_ids, var.public_subnet_ids)
    security_group_ids      = [aws_security_group.cluster.id]
    endpoint_private_access = true
    endpoint_public_access  = true
  }

  enabled_cluster_log_types = [
    "api", "audit", "authenticator", "controllerManager", "scheduler"
  ]

  encryption_config {
    provider { key_arn = aws_kms_key.eks.arn }
    resources = ["secrets"]
  }

  depends_on = [
    aws_cloudwatch_log_group.eks,
    aws_iam_role_policy_attachment.eks_cluster_AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.eks_cluster_AmazonEKSServicePolicy
  ]
}

# -------- Node IAM --------

resource "aws_iam_role" "nodes" {
  name = "${local.cluster_name}-nodes-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "nodes_AmazonEKSWorkerNodePolicy" {
  role       = aws_iam_role.nodes.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "nodes_AmazonEC2ContainerRegistryReadOnly" {
  role       = aws_iam_role.nodes.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "nodes_AmazonEKS_CNI_Policy" {
  role       = aws_iam_role.nodes.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}


# -------- Node groups (no aws-auth dependency) --------

resource "aws_eks_node_group" "ng_general" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "ng-general"
  node_role_arn   = aws_iam_role.nodes.arn
  subnet_ids      = var.private_subnet_ids

  scaling_config {
    desired_size = var.desired_ng1_size
    max_size     = var.desired_ng1_size + 2
    min_size     = max(1, var.desired_ng1_size - 1)
  }

  instance_types = [var.node_instance_type]
  ami_type       = "AL2_x86_64"
  capacity_type  = "ON_DEMAND"
  disk_size      = 50

  remote_access {
    ec2_ssh_key               = var.ssh_key_name
    source_security_group_ids = [aws_security_group.nodes.id]
  }

  update_config {
    max_unavailable = 1
  }

  depends_on = [
    aws_iam_role_policy_attachment.nodes_AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.nodes_AmazonEC2ContainerRegistryReadOnly,
    aws_iam_role_policy_attachment.nodes_AmazonEKS_CNI_Policy
  ]
}

resource "aws_eks_node_group" "ng_system" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "ng-system"
  node_role_arn   = aws_iam_role.nodes.arn
  subnet_ids      = var.private_subnet_ids

  scaling_config {
    desired_size = var.desired_ng2_size
    max_size     = var.desired_ng2_size + 2
    min_size     = max(1, var.desired_ng2_size - 1)
  }

  instance_types = [var.node_instance_type]
  ami_type       = "AL2_x86_64"
  capacity_type  = "ON_DEMAND"
  disk_size      = 50

  update_config {
    max_unavailable = 1
  }

  depends_on = [
    aws_iam_role_policy_attachment.nodes_AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.nodes_AmazonEC2ContainerRegistryReadOnly,
    aws_iam_role_policy_attachment.nodes_AmazonEKS_CNI_Policy
  ]
}

# -------- OIDC + IRSA + AWS Load Balancer Controller --------

data "tls_certificate" "eks" {
  url = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

data "aws_iam_policy_document" "alb_assume" {
  statement {
    effect = "Allow"

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.eks.arn]
    }

    actions = ["sts:AssumeRoleWithWebIdentity"]

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:aws-load-balancer-controller"]
    }
  }
}

resource "aws_iam_role" "alb_irsa" {
  name               = "${local.cluster_name}-alb-controller"
  assume_role_policy = data.aws_iam_policy_document.alb_assume.json
}

resource "aws_iam_policy" "alb_controller" {
  name   = "${local.cluster_name}-alb-policy"
  policy = file("${path.module}/policies/aws_load_balancer_controller_policy.json")
}

resource "aws_iam_role_policy_attachment" "alb_attach" {
  role       = aws_iam_role.alb_irsa.name
  policy_arn = aws_iam_policy.alb_controller.arn
}

resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"

  create_namespace = false

  values = [
    yamlencode({
      clusterName = aws_eks_cluster.this.name
      region      = var.aws_region
      vpcId       = var.vpc_id
      serviceAccount = {
        create = true
        name   = "aws-load-balancer-controller"
        annotations = {
          "eks.amazonaws.com/role-arn" = aws_iam_role.alb_irsa.arn
        }
      }
    })
  ]

  depends_on = [
    aws_iam_role_policy_attachment.alb_attach,
    aws_eks_node_group.ng_general,
    aws_eks_node_group.ng_system
  ]
}

# -------- Supporting services --------

data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "eks_logs" {
  bucket = "${local.cluster_name}-app-logs-${data.aws_caller_identity.current.account_id}"
}

resource "aws_ecr_repository" "app" {
  name = "${local.cluster_name}-app"

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_guardduty_detector" "this" {
  enable = true
}
