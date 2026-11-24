# Infrastructure de demonstration TaskFlow (AWS)
# TP 4 - Securisation Infrastructure as Code
#
# Infrastructure fictive pour les analyses Checkov.
# Ne pas executer terraform apply sans validation.


# ==========================================
# CONFIGURATION TERRAFORM
# ==========================================

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

# Bucket de centralisation des journaux S3
variable "s3_access_logs_bucket" {
  description = "Nom du bucket existant pour les journaux S3"
  type        = string
}

# Recuperer automatiquement l'identifiant du compte AWS
data "aws_caller_identity" "current" {}


# ==========================================
# STOCKAGE S3
# ==========================================

resource "aws_s3_bucket" "exports" {

  #checkov:skip=CKV_AWS_144:TP demonstration - Replication interregionale non active pour limiter les couts. Revue avant le 2027-01-31.

  bucket = "taskflow-exports-demo"
}

# ==========================================
# NOTIFICATIONS DES EVENEMENTS S3
# ==========================================

resource "aws_s3_bucket_notification" "exports" {
  bucket = aws_s3_bucket.exports.id

  # Envoyer les evenements du bucket vers EventBridge
  eventbridge = true
}
# ==========================================
# JOURNALISATION DES ACCES S3
# ==========================================

resource "aws_s3_bucket_logging" "exports" {
  bucket = aws_s3_bucket.exports.id

  # Destination des journaux
  target_bucket = var.s3_access_logs_bucket
  target_prefix = "taskflow-exports/"
}

# ==========================================
# PROTECTION CONTRE LES ACCES PUBLICS
# ==========================================

resource "aws_s3_bucket_public_access_block" "exports" {
  bucket = aws_s3_bucket.exports.id

  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}


# ==========================================
# CLE KMS ET POLITIQUE DE SECURITE
# ==========================================

resource "aws_kms_key" "s3" {
  description         = "Cle de chiffrement S3 TaskFlow"
  enable_key_rotation = true

  # Autoriser l'administration de la cle via les droits IAM du compte AWS
  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Sid    = "EnableIAMUserPermissions"
        Effect = "Allow"

        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }

        Action   = "kms:*"
        Resource = "*"
      }
    ]
  })
}


# ==========================================
# CHIFFREMENT S3 AVEC KMS
# ==========================================

resource "aws_s3_bucket_server_side_encryption_configuration" "exports" {
  bucket = aws_s3_bucket.exports.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.s3.arn
    }

    bucket_key_enabled = true
  }
}


# ==========================================
# VERSIONING S3
# ==========================================

resource "aws_s3_bucket_versioning" "exports" {
  bucket = aws_s3_bucket.exports.id

  versioning_configuration {
    status = "Enabled"
  }
}


# ==========================================
# CYCLE DE VIE DES OBJETS S3
# ==========================================

resource "aws_s3_bucket_lifecycle_configuration" "exports" {
  bucket = aws_s3_bucket.exports.id

  rule {
    id     = "nettoyage-uploads-incomplets"
    status = "Enabled"

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}


# ==========================================
# SECURITE RESEAU
# ==========================================

resource "aws_security_group" "web" {
  name        = "taskflow-web"
  description = "Acces restreint a l'API TaskFlow"

  # API accessible uniquement depuis le reseau prive
  ingress {
    description = "API TaskFlow depuis le reseau prive"

    from_port   = 8085
    to_port     = 8085
    protocol    = "tcp"

    cidr_blocks = ["10.0.0.0/8"]
  }

  # Autoriser uniquement les connexions HTTPS sortantes
  egress {
    description = "HTTPS sortant pour les services externes"

    from_port   = 443
    to_port     = 443
    protocol    = "tcp"

    cidr_blocks = ["0.0.0.0/0"]
  }
}


# ==========================================
# IDENTITE IAM DE L'INSTANCE EC2
# ==========================================

resource "aws_iam_role" "api" {
  name = "taskflow-api-role"

  # Seules les instances EC2 peuvent utiliser ce role
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
}

# Associer le role IAM aux instances EC2
resource "aws_iam_instance_profile" "api" {
  name = "taskflow-api-profile"
  role = aws_iam_role.api.name
}


# ==========================================
# INSTANCE EC2
# ==========================================

resource "aws_instance" "api" {

  # AMI fictive utilisee pour le TP
  ami           = "ami-0123456789abcdef0"
  instance_type = "t3.micro"

  # Associer le role IAM
  iam_instance_profile = aws_iam_instance_profile.api.name

  # Associer le groupe de securite
  vpc_security_group_ids = [
    aws_security_group.web.id
  ]

  # Activer la surveillance detaillee
  monitoring = true

  # Optimiser les performances EBS
  ebs_optimized = true

  # Imposer IMDSv2
  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  # Chiffrer le disque principal
  root_block_device {
    volume_size = 20
    encrypted   = true
  }

  tags = {
    Name = "taskflow-api"
  }
}


# ==========================================
# SURVEILLANCE AVANCEE RDS
# ==========================================

resource "aws_iam_role" "rds_monitoring" {
  name = "taskflow-rds-monitoring"

  # Autoriser RDS a utiliser ce role
  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })
}

# Autoriser RDS a envoyer les metriques vers CloudWatch
resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  role       = aws_iam_role.rds_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# ==========================================
# JOURNALISATION POSTGRESQL
# ==========================================

resource "aws_db_parameter_group" "tasks" {
  name   = "taskflow-postgres-logs"
  family = "postgres16"

  # Journaliser les modifications de structure SQL
  parameter {
    name  = "log_statement"
    value = "ddl"
  }

  # Journaliser les requetes superieures a 1 seconde
  parameter {
    name  = "log_min_duration_statement"
    value = "1000"
  }

  # Imposer les connexions chiffrees
  parameter {
    name  = "rds.force_ssl"
    value = "1"
  }
}

# ==========================================
# BASE DE DONNEES RDS
# ==========================================

resource "aws_db_instance" "tasks" {

  #checkov:skip=CKV_AWS_157:TP demonstration - Multi-AZ non active pour limiter les couts. Revue avant le 2027-01-31.

  identifier        = "taskflow-db"
  engine            = "postgres"

# Utiliser notre groupe de parametres securise
  parameter_group_name = aws_db_parameter_group.tasks.name
  instance_class    = "db.t3.micro"
  allocated_storage = 20

  # Identifiant de connexion
  username = "taskflow"

  # Mot de passe gere par AWS Secrets Manager
  manage_master_user_password = true

  # Interdire l'acces public
  publicly_accessible = false

  # Activer le chiffrement de la base
  storage_encrypted = true

  # Activer l'authentification IAM
  iam_database_authentication_enabled = true

  # Installer automatiquement les mises a jour mineures
  auto_minor_version_upgrade = true

  # Conserver les tags sur les snapshots
  copy_tags_to_snapshot = true

 # Activer les informations de performance
performance_insights_enabled = true

# Chiffrer les donnees de performance avec notre cle KMS
performance_insights_kms_key_id = aws_kms_key.rds.arn

# Activer la surveillance avancee toutes les 60 secondes
monitoring_interval = 60

# Role IAM utilise par Enhanced Monitoring
monitoring_role_arn = aws_iam_role.rds_monitoring.arn

# S'assurer que les autorisations sont attachees avant la creation
depends_on = [
  aws_iam_role_policy_attachment.rds_monitoring
]

  # Exporter les journaux PostgreSQL
  enabled_cloudwatch_logs_exports = [
    "postgresql",
    "upgrade"
  ]

  # Eviter la suppression accidentelle
  deletion_protection = true

  # Conserver un snapshot final
  skip_final_snapshot       = false
  final_snapshot_identifier = "taskflow-db-final"
}