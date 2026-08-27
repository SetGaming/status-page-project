data "http" "aws_load_balancer_controller_iam_policy" {
  url = "https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v3.5.0/docs/install/iam_policy.json"
}

data "aws_iam_policy_document" "aws_load_balancer_controller_pod_identity" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }

    actions = [
      "sts:AssumeRole",
      "sts:TagSession"
    ]
  }
}

resource "aws_iam_policy" "aws_load_balancer_controller" {
  name   = "avivneta-${var.project_name}-${var.environment}-aws-load-balancer-controller"
  policy = data.http.aws_load_balancer_controller_iam_policy.response_body
}

resource "aws_iam_role" "aws_load_balancer_controller" {
  name               = "avivneta-${var.project_name}-${var.environment}-aws-load-balancer-controller-role"
  assume_role_policy = data.aws_iam_policy_document.aws_load_balancer_controller_pod_identity.json

  tags = {
    Name = "avivneta-${var.project_name}-${var.environment}-aws-load-balancer-controller-role"
  }
}

resource "aws_iam_role_policy_attachment" "aws_load_balancer_controller" {
  role       = aws_iam_role.aws_load_balancer_controller.name
  policy_arn = aws_iam_policy.aws_load_balancer_controller.arn
}

resource "aws_eks_pod_identity_association" "aws_load_balancer_controller" {
  cluster_name    = aws_eks_cluster.main.name
  namespace       = "kube-system"
  service_account = "aws-load-balancer-controller"
  role_arn        = aws_iam_role.aws_load_balancer_controller.arn

  depends_on = [
    aws_eks_addon.pod_identity_agent,
    aws_iam_role_policy_attachment.aws_load_balancer_controller
  ]
}

resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = "3.5.0"
  namespace  = "kube-system"

  timeout = 600
  wait    = true

  values = [
    yamlencode({
      clusterName = aws_eks_cluster.main.name
      region      = var.aws_region
      vpcId       = aws_vpc.main.id

      serviceAccount = {
        create = true
        name   = "aws-load-balancer-controller"
      }
    })
  ]

  depends_on = [
    aws_eks_node_group.main,
    aws_eks_pod_identity_association.aws_load_balancer_controller
  ]
}
