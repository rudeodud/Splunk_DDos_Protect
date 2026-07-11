resource "aws_iam_role" "app" {
  name = "${local.name_prefix}-app-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_instance_profile" "app" {
  name = "${local.name_prefix}-app-profile"
  role = aws_iam_role.app.name
}

resource "aws_iam_role_policy" "app_hec_token_ssm" {
  count = var.splunk_hec_token_ssm_parameter_name != "" ? 1 : 0
  name  = "${local.name_prefix}-read-hec-token"
  role  = aws_iam_role.app.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "ssm:GetParameter"
      ]
      Resource = "arn:aws:ssm:${var.aws_region}:*:parameter/${trimprefix(var.splunk_hec_token_ssm_parameter_name, "/")}"
    }]
  })
}
