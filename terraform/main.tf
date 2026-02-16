# --- Networking: VPC, subnets, S3 gateway endpoint ---
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.8.1"

  name                 = "${var.project_name}-vpc"
  cidr                 = "10.100.0.0/16"
  azs                  = slice(data.aws_availability_zones.available.names, 0, 2)
  private_subnets      = ["10.100.1.0/24", "10.100.2.0/24"]
  public_subnets       = ["10.100.101.0/24", "10.100.102.0/24"]
  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags                 = merge(var.tags, { Name = "${var.project_name}-vpc" })
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = module.vpc.vpc_id
  service_name      = "com.amazonaws.${data.aws_region.current.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = module.vpc.private_route_table_ids
  tags              = merge(var.tags, { Name = "${var.project_name}-s3-ep" })
}

# --- Single S3 bucket: app logs, libraries, and tests ---
resource "aws_s3_bucket" "emr" {
  bucket        = "${var.project_name}-bucket-${data.aws_caller_identity.current.account_id}"
  force_destroy = true
  tags          = merge(var.tags, { Name = "${var.project_name}-bucket" })
}

resource "aws_s3_bucket_public_access_block" "emr" {
  bucket = aws_s3_bucket.emr.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# --- Logging ---
resource "aws_cloudwatch_log_group" "emr" {
  name              = "/aws/emr-serverless/${var.project_name}"
  retention_in_days = 7
  tags              = merge(var.tags, { Name = "${var.project_name}-log-group" })
}

# --- Security group for EMR Serverless and EMR Studio (egress only) ---
resource "aws_security_group" "emr_serverless" {
  name        = "${var.project_name}-serverless-sg"
  description = "EMR Serverless and EMR Studio, all outbound allowed"
  vpc_id      = module.vpc.vpc_id
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = merge(var.tags, { Name = "${var.project_name}-serverless-sg" })
}

# --- IAM: EMR Serverless execution role ---
resource "aws_iam_role" "emr_serverless_execution" {
  name               = "${var.project_name}-execution-role"
  assume_role_policy = data.aws_iam_policy_document.emr_serverless_assume.json
  tags               = merge(var.tags, { Name = "${var.project_name}-execution-role" })
}
resource "aws_iam_role_policy" "emr_serverless_execution" {
  name   = "${var.project_name}-execution-policy"
  role   = aws_iam_role.emr_serverless_execution.id
  policy = data.aws_iam_policy_document.emr_serverless_execution.json
}

# --- EMR Serverless application (VPC: private subnets + security group) ---
resource "aws_emrserverless_application" "main" {
  name          = "${var.project_name}-app"
  release_label = var.emr_release_label
  type          = var.emr_serverless.application_type
  architecture  = var.emr_serverless.architecture

  auto_start_configuration {
    enabled = true
  }
  auto_stop_configuration {
    enabled              = true
    idle_timeout_minutes = var.emr_serverless.auto_stop_idle_minutes
  }

  network_configuration {
    subnet_ids         = module.vpc.private_subnets
    security_group_ids = [aws_security_group.emr_serverless.id]
  }

  initial_capacity {
    initial_capacity_type = "Driver"
    initial_capacity_config {
      worker_count = var.emr_serverless.driver.worker_count
      worker_configuration {
        cpu    = var.emr_serverless.driver.cpu
        memory = var.emr_serverless.driver.memory
        disk   = var.emr_serverless.driver.disk
      }
    }
  }
  initial_capacity {
    initial_capacity_type = "Executor"
    initial_capacity_config {
      worker_count = var.emr_serverless.executor.worker_count
      worker_configuration {
        cpu    = var.emr_serverless.executor.cpu
        memory = var.emr_serverless.executor.memory
        disk   = var.emr_serverless.executor.disk
      }
    }
  }
  maximum_capacity {
    cpu    = var.emr_serverless.maximum_capacity.cpu
    memory = var.emr_serverless.maximum_capacity.memory
    disk   = var.emr_serverless.maximum_capacity.disk
  }

  tags = var.tags
}

# --- IAM: EMR Studio role and managed policy attachments ---
resource "aws_iam_role" "emr_studio" {
  name               = "${var.project_name}-studio-role"
  assume_role_policy = data.aws_iam_policy_document.emr_studio_assume.json
  tags               = merge(var.tags, { Name = "${var.project_name}-studio-role" })
}
resource "aws_iam_role_policy_attachment" "emr_studio_editors" {
  role       = aws_iam_role.emr_studio.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AmazonElasticMapReduceEditorsRole"
}
resource "aws_iam_role_policy_attachment" "emr_studio_s3" {
  role       = aws_iam_role.emr_studio.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonS3FullAccess"
}
resource "aws_iam_role_policy_attachment" "emr_studio_emr" {
  role       = aws_iam_role.emr_studio.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonElasticMapReduceFullAccess"
}

# --- EMR Studio ---
resource "aws_emr_studio" "main" {
  name                        = "${var.project_name}-studio"
  auth_mode                   = "IAM"
  vpc_id                      = module.vpc.vpc_id
  subnet_ids                  = module.vpc.private_subnets
  service_role                = aws_iam_role.emr_studio.arn
  workspace_security_group_id = aws_security_group.emr_serverless.id
  engine_security_group_id    = aws_security_group.emr_serverless.id
  default_s3_location         = "s3://${aws_s3_bucket.emr.id}/studio/"
  tags                        = var.tags
}
