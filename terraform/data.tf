# --- Data: AZs, account, region ---
data "aws_availability_zones" "available" {
  state = "available"
}
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_partition" "current" {}

# --- Data: IAM policy documents ---
data "aws_iam_policy_document" "emr_studio_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["elasticmapreduce.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "emr_serverless_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["emr-serverless.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "emr_serverless_execution" {
  # EMR Serverless needs to pull runtime artifacts (Spark, dependencies) from AWS-managed elasticmapreduce buckets.
  statement {
    sid     = "EmrManagedS3"
    effect  = "Allow"
    actions = ["s3:GetObject", "s3:ListBucket"]
    resources = [
      "arn:${data.aws_partition.current.partition}:s3:::*.elasticmapreduce",
      "arn:${data.aws_partition.current.partition}:s3:::*.elasticmapreduce/*"
    ]
  }
  # Jobs read/write scripts, data, logs, and test outputs in the single project bucket.
  statement {
    sid       = "S3Access"
    effect    = "Allow"
    actions   = ["s3:PutObject", "s3:GetObject", "s3:ListBucket", "s3:DeleteObject"]
    resources = [aws_s3_bucket.emr.arn, "${aws_s3_bucket.emr.arn}/*"]
  }
  # Workers run in the VPC and need to create/delete ENIs and describe subnets/SGs/endpoints; scope to this VPC only.
  statement {
    sid       = "VpcEni"
    effect    = "Allow"
    actions   = ["ec2:CreateNetworkInterface", "ec2:DeleteNetworkInterface", "ec2:DescribeNetworkInterfaces", "ec2:DescribeSubnets", "ec2:DescribeSecurityGroups", "ec2:DescribeVpcEndpoints"]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "ec2:Vpc"
      values   = [module.vpc.vpc_arn]
    }
  }
  # Driver and executors send logs to the designated CloudWatch log group.
  statement {
    sid       = "CloudWatchLogs"
    effect    = "Allow"
    actions   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents", "logs:DescribeLogGroups"]
    resources = [aws_cloudwatch_log_group.emr.arn, "${aws_cloudwatch_log_group.emr.arn}:*", "*"]
  }
}
