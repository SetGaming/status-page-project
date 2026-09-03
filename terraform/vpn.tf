# =========================================================
# Client VPN
# =========================================================

# ---------------------------------------------------------
# Certificate Authority
# ---------------------------------------------------------

resource "tls_private_key" "vpn_ca" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "vpn_ca" {
  private_key_pem = tls_private_key.vpn_ca.private_key_pem

  subject {
    common_name  = "status-page-vpn-ca"
    organization = "status-page"
  }

  validity_period_hours = 8760

  is_ca_certificate    = true
  set_authority_key_id = true

  allowed_uses = [
    "cert_signing",
    "crl_signing"
  ]
}

# ---------------------------------------------------------
# VPN Server Certificate
# ---------------------------------------------------------

resource "tls_private_key" "vpn_server" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_cert_request" "vpn_server" {
  private_key_pem = tls_private_key.vpn_server.private_key_pem

  subject {
    common_name  = "vpn.avivneta-statuspage.com"
    organization = "status-page"
  }

  dns_names = [
    "vpn.avivneta-statuspage.com"
  ]
}

resource "tls_locally_signed_cert" "vpn_server" {
  cert_request_pem   = tls_cert_request.vpn_server.cert_request_pem
  ca_private_key_pem = tls_private_key.vpn_ca.private_key_pem
  ca_cert_pem        = tls_self_signed_cert.vpn_ca.cert_pem

  validity_period_hours = 8760

  allowed_uses = [
    "server_auth"
  ]
}

# ---------------------------------------------------------
# VPN Client Certificate
# ---------------------------------------------------------

resource "tls_private_key" "vpn_client" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_cert_request" "vpn_client" {
  private_key_pem = tls_private_key.vpn_client.private_key_pem

  subject {
    common_name  = "status-page-vpn-client"
    organization = "status-page"
  }
}

resource "tls_locally_signed_cert" "vpn_client" {
  cert_request_pem   = tls_cert_request.vpn_client.cert_request_pem
  ca_private_key_pem = tls_private_key.vpn_ca.private_key_pem
  ca_cert_pem        = tls_self_signed_cert.vpn_ca.cert_pem

  validity_period_hours = 8760

  allowed_uses = [
    "client_auth"
  ]
}

# ---------------------------------------------------------
# Import certificates into AWS ACM
# ---------------------------------------------------------

resource "aws_acm_certificate" "vpn_ca" {
  private_key      = tls_private_key.vpn_ca.private_key_pem
  certificate_body = tls_self_signed_cert.vpn_ca.cert_pem

  tags = {
    Name = "avivneta-status-page-vpn-ca"
  }
}

resource "aws_acm_certificate" "vpn_server" {
  private_key       = tls_private_key.vpn_server.private_key_pem
  certificate_body  = tls_locally_signed_cert.vpn_server.cert_pem
  certificate_chain = tls_self_signed_cert.vpn_ca.cert_pem

  tags = {
    Name = "avivneta-status-page-vpn-server"
  }
}

# ---------------------------------------------------------
# Security Group for VPN clients
# ---------------------------------------------------------

resource "aws_security_group" "client_vpn" {
  name_prefix = "avivneta-${var.project_name}-${var.environment}-client-vpn-"
  description = "Security group for Client VPN"
  vpc_id      = aws_vpc.main.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "avivneta-${var.project_name}-${var.environment}-client-vpn-sg"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ---------------------------------------------------------
# AWS Client VPN Endpoint
# ---------------------------------------------------------

resource "aws_ec2_client_vpn_endpoint" "main" {
  description            = "Status Page Client VPN"
  server_certificate_arn = aws_acm_certificate.vpn_server.arn

  client_cidr_block = "10.100.0.0/22"

  split_tunnel = true

  authentication_options {
    type                       = "certificate-authentication"
    root_certificate_chain_arn = aws_acm_certificate.vpn_ca.arn
  }

  connection_log_options {
    enabled = false
  }

  security_group_ids = [
    aws_security_group.client_vpn.id
  ]

  vpc_id = aws_vpc.main.id

  tags = {
    Name = "avivneta-${var.project_name}-${var.environment}-client-vpn"
  }
}

# ---------------------------------------------------------
# Connect VPN to the private network
# ---------------------------------------------------------

resource "aws_ec2_client_vpn_network_association" "private_1" {
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.main.id
  subnet_id              = aws_subnet.private[0].id
}

# ---------------------------------------------------------
# Allow VPN clients to access the VPC
# ---------------------------------------------------------

resource "aws_ec2_client_vpn_route" "vpc" {
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.main.id
  destination_cidr_block = var.vpc_cidr
  target_vpc_subnet_id   = aws_subnet.private[0].id
  description            = "Default Route"
}

resource "aws_ec2_client_vpn_authorization_rule" "vpc" {
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.main.id
  target_network_cidr    = var.vpc_cidr

  authorize_all_groups = true
}

# ---------------------------------------------------------
# VPN Client Outputs
# ---------------------------------------------------------

output "vpn_client_certificate" {
  value     = tls_locally_signed_cert.vpn_client.cert_pem
  sensitive = true
}

output "vpn_client_private_key" {
  value     = tls_private_key.vpn_client.private_key_pem
  sensitive = true
}
