provider "aws" {
  profile = "cloud-admin"
  region  = "us-east-1"
}

# S3 bucket for clinical trial data (all lowercase, globally unique)
resource "aws_s3_bucket" "clinical_data" {
  bucket = "clinical-trial-data-demo-dolutegravir-vs-cabotegravir"
}

# IAM Groups
resource "aws_iam_group" "researchers" {
  name = "researchers"
}
resource "aws_iam_group" "coordinators" {
  name = "coordinators"
}
resource "aws_iam_group" "auditors" {
  name = "auditors"
}

# IAM Users
resource "aws_iam_user" "takop" { name = "takop" }
resource "aws_iam_user" "nouyou"   { name = "nouyou" }
resource "aws_iam_user" "emade" { name = "emade" }

# Memberships
resource "aws_iam_user_group_membership" "takop_group" {
  user   = aws_iam_user.takop.name
  groups = [aws_iam_group.researchers.name]
}
resource "aws_iam_user_group_membership" "nouyou_group" {
  user   = aws_iam_user.nouyou.name
  groups = [aws_iam_group.coordinators.name]
}
resource "aws_iam_user_group_membership" "emade_group" {
  user   = aws_iam_user.emade.name
  groups = [aws_iam_group.auditors.name]
}

# Policies
## Researchers: read/write
data "aws_iam_policy_document" "researchers_policy_doc" {
  statement {
    actions   = ["s3:ListBucket","s3:GetObject","s3:PutObject","s3:DeleteObject"]
    resources = [
      aws_s3_bucket.clinical_data.arn,
      "${aws_s3_bucket.clinical_data.arn}/*"
    ]
  }
}
resource "aws_iam_policy" "researchers_policy" {
  name   = "researchers-policy"
  policy = data.aws_iam_policy_document.researchers_policy_doc.json
}
resource "aws_iam_group_policy_attachment" "attach_researchers" {
  group      = aws_iam_group.researchers.name
  policy_arn = aws_iam_policy.researchers_policy.arn
}

## Coordinators: write‑only
data "aws_iam_policy_document" "coordinators_policy_doc" {
  statement {
    effect    = "Allow"
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.clinical_data.arn}/*"]
  }
}
resource "aws_iam_policy" "coordinators_policy" {
  name   = "coordinators-policy"
  policy = data.aws_iam_policy_document.coordinators_policy_doc.json
}
resource "aws_iam_group_policy_attachment" "attach_coordinators" {
  group      = aws_iam_group.coordinators.name
  policy_arn = aws_iam_policy.coordinators_policy.arn
}

## Auditors: read‑only
data "aws_iam_policy_document" "auditors_policy_doc" {
  statement {
    effect    = "Allow"
    actions   = ["s3:ListBucket","s3:GetObject"]
    resources = [
      aws_s3_bucket.clinical_data.arn,
      "${aws_s3_bucket.clinical_data.arn}/*"
    ]
  }
}
resource "aws_iam_policy" "auditors_policy" {
  name   = "auditors-policy"
  policy = data.aws_iam_policy_document.auditors_policy_doc.json
}
resource "aws_iam_group_policy_attachment" "attach_auditors" {
  group      = aws_iam_group.auditors.name
  policy_arn = aws_iam_policy.auditors_policy.arn
}

# Role for temporary elevated access (assume by takop)
data "aws_iam_policy_document" "assume_role_policy_doc" {
  statement {
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = [
        aws_iam_user.takop.arn
      ]
    }
    actions = ["sts:AssumeRole"]
  }
}
resource "aws_iam_role" "TrialDataAnalystRole" {
  name               = "TrialDataAnalystRole"
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy_doc.json
}
data "aws_iam_policy_document" "analyst_policy_doc" {
  statement {
    effect    = "Allow"
    actions   = ["s3:ListBucket","s3:GetObject","s3:PutObject","s3:DeleteObject"]
    resources = [
      aws_s3_bucket.clinical_data.arn,
      "${aws_s3_bucket.clinical_data.arn}/*"
    ]
  }
}
resource "aws_iam_policy" "analyst_policy" {
  name   = "analyst-policy"
  policy = data.aws_iam_policy_document.analyst_policy_doc.json
}
resource "aws_iam_role_policy_attachment" "attach_analyst_policy" {
  role       = aws_iam_role.TrialDataAnalystRole.name
  policy_arn = aws_iam_policy.analyst_policy.arn
}

# Outputs
output "bucket_name" {
  value = aws_s3_bucket.clinical_data.bucket
}
output "analyst_role_arn" {
  value = aws_iam_role.TrialDataAnalystRole.arn
}
