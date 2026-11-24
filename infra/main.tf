# Infrastructure de demonstration TaskFlow (AWS)
# Configuration renforcee pour le TP DevSecOps.
#
# ATTENTION :
# Ce fichier est uniquement destine a l'analyse de securite.
# Ne pas executer terraform apply sans validation de l'architecture.

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "eu-west-3"
}


# ==========================================
# STOCKAGE S3
# ==========================================

resource "aws_s3_bucket" "exports" {
  bucket = "taskflow-exports-demo"
}

# Interdire les acces publics au bucket
resource "aws_s3_bucket_public_access_block" "exports" {
  bucket = aws_s3_bucket.exports.id

  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}


# ==========================================
# SECURITE RESEAU
# ==========================================

resource "aws_security_group" "web" {
  name        = "taskflow-web"
  description = "Acces restreint a l'API TaskFlow"

  # Acces a l'API depuis un reseau prive de demonstration
  # A adapter au VPC utilise avant tout deploiement.
  ingress {
    from_port   = 8085
    to_port     = 8085
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
  }

  # Trafic sortant
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


# ==========================================
# INSTANCE EC2
# ==========================================

resource "aws_instance" "api" {
  # Identifiant fictif pour les besoins du TP
  ami           = "ami-0123456789abcdef0"
  instance_type = "t3.micro"

  vpc_security_group_ids = [
    aws_security_group.web.id
  ]

  root_block_device {
    volume_size = 20
    encrypted   = true
  }

  tags = {
    Name = "taskflow-api"
  }
}


# ==========================================
# BASE DE DONNEES RDS
# ==========================================

resource "aws_db_instance" "tasks" {
  identifier        = "taskflow-db"
  engine            = "postgres"
  instance_class    = "db.t3.micro"
  allocated_storage = 20

  username = "taskflow"

  # Mot de passe gere par AWS Secrets Manager
  manage_master_user_password = true

  # Desactiver l'acces public
  publicly_accessible = false

  # Activer le chiffrement
  storage_encrypted = true

  # Exporter les journaux PostgreSQL vers CloudWatch
  enabled_cloudwatch_logs_exports = [
    "postgresql",
    "upgrade"
  ]

  # Eviter la suppression accidentelle de la base
  deletion_protection = true

  # Conserver un snapshot final
  skip_final_snapshot       = false
  final_snapshot_identifier = "taskflow-db-final"
}