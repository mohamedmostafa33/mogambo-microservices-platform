resource "aws_security_group" "mogambo_alb_sg" {
  name        = "mogambo-alb-sg"
  description = "Security group for the Mogambo Application Load Balancer"
  vpc_id      = var.vpc_id

  tags = {
    Name = "mogambo-alb-sg"
  }
}

resource "aws_security_group" "mogambo_eks_node_group_sg" {
  name        = "mogambo-eks-node-group-sg"
  description = "Security group for the Mogambo EKS Node Group"
  vpc_id      = var.vpc_id

  tags = {
    Name = "mogambo-eks-node-group-sg"
  }
}

resource "aws_security_group" "mogambo_catalogue_db_sg" {
  name        = "mogambo-catalogue-db-sg"
  description = "Security group for the Mogambo Catalogue Database"
  vpc_id      = var.vpc_id

  tags = {
    Name = "mogambo-catalogue-db-sg"
  }
}

resource "aws_security_group" "mogambo_sonarqube_sg" {
  name        = "mogambo-sonarqube-sg"
  description = "Security group for the Mogambo SonarQube instance"
  vpc_id      = var.vpc_id

  tags = {
    Name = "mogambo-sonarqube-sg"
  }
}

resource "aws_security_group_rule" "allow_alb_to_eks_node_group" {
  description              = "Allow ALB to communicate with EKS node group"
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.mogambo_eks_node_group_sg.id
  source_security_group_id = aws_security_group.mogambo_alb_sg.id
}

resource "aws_security_group_rule" "allow_alb_all_egress" {
  description       = "Allow all outbound traffic from ALB"
  type              = "egress"
  security_group_id = aws_security_group.mogambo_alb_sg.id
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "allow_http_inbound_to_alb" {
  description       = "Allow HTTP inbound traffic to ALB from the internet"
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  security_group_id = aws_security_group.mogambo_alb_sg.id
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "allow_https_inbound_to_alb" {
  description       = "Allow HTTPS inbound traffic to ALB from the internet"
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  security_group_id = aws_security_group.mogambo_alb_sg.id
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "allow_nodeport_access_from_alb" {
  description              = "Allow NodePort access from ALB"
  type                     = "ingress"
  from_port                = 30000
  to_port                  = 32767
  protocol                 = "tcp"
  security_group_id        = aws_security_group.mogambo_eks_node_group_sg.id
  source_security_group_id = aws_security_group.mogambo_alb_sg.id
}

resource "aws_security_group_rule" "allow_node_to_node_communication" {
  description              = "Allow Node to Node communication within EKS cluster"
  type                     = "ingress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  security_group_id        = aws_security_group.mogambo_eks_node_group_sg.id
  source_security_group_id = aws_security_group.mogambo_eks_node_group_sg.id
}

resource "aws_security_group_rule" "allow_all_egress_from_eks_nodes" {
  description       = "Allow all outbound traffic from EKS nodes (via NAT)"
  type              = "egress"
  security_group_id = aws_security_group.mogambo_eks_node_group_sg.id
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "allow_db_access_from_eks" {
  description              = "Allow EKS node group to access RDS"
  type                     = "ingress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  security_group_id        = aws_security_group.mogambo_catalogue_db_sg.id
  source_security_group_id = aws_security_group.mogambo_eks_node_group_sg.id
}

resource "aws_security_group_rule" "allow_db_all_egress" {
  description       = "Allow all outbound traffic (via NAT)"
  type              = "egress"
  security_group_id = aws_security_group.mogambo_catalogue_db_sg.id
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "allow_sonarqube_ssh_ingress" {
  description              = "Allow SSH access to SonarQube instance"
  type                     = "ingress"
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  security_group_id        = aws_security_group.mogambo_sonarqube_sg.id
  cidr_blocks              = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "allow_sonarqube_ingress" {
  description              = "Allow inbound traffic to SonarQube"
  type                     = "ingress"
  from_port                = 9000
  to_port                  = 9000
  protocol                 = "tcp"
  security_group_id        = aws_security_group.mogambo_sonarqube_sg.id
  cidr_blocks              = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "allow_sonarqube_egress" {
  description       = "Allow outbound traffic from SonarQube"
  type              = "egress"
  security_group_id = aws_security_group.mogambo_sonarqube_sg.id
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
}