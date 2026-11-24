variable "name" {
  type = string
}

data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "host" {
  name               = "${var.name}-host-role"
  assume_role_policy = data.aws_iam_policy_document.assume.json
}

# Session Manager: a keyless fallback if SSH ever breaks
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.host.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Jenkins pushes images and k3s pulls them. PowerUser is simple; tighten it later.
resource "aws_iam_role_policy_attachment" "ecr" {
  role       = aws_iam_role.host.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser"
}

resource "aws_iam_instance_profile" "host" {
  name = "${var.name}-host-profile"
  role = aws_iam_role.host.name
}

output "instance_profile_name" {
  value = aws_iam_instance_profile.host.name
}
