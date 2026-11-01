resource "aws_iam_role" "ssm_ec2_role" {
  name = "${var.project_name}-ssm-ec2-role"

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

  tags = {
    Name = "${var.project_name}-ssm-ec2-role"
  }
}

resource "aws_iam_role_policy_attachment" "ssm_managed_instance_core" {
  role       = aws_iam_role.ssm_ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ssm_ec2" {
  name = "${var.project_name}-ssm-ec2-profile"
  role = aws_iam_role.ssm_ec2_role.name

  tags = {
    Name = "${var.project_name}-ssm-ec2-profile"
  }
}
