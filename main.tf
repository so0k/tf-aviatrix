# set up Role for Aviatrix AWS Integration
# https://s3-us-west-2.amazonaws.com/aviatrix-download/iam_assume_role_policy.txt
# https://s3-us-west-2.amazonaws.com/aviatrix-download/IAM_access_policy_for_CloudN.txt
variable "region" {
  default = "ap-southeast-1"
}

variable "aviatrix_account" {
  default = "831229805065"
}

# provided in terraform.tfvars
variable "aviatrix_token" {
  description = "Aviatrix token (24hrs) to link account"
}

# provided in terraform.tfvars
variable "aviatrix_client_id" {
  description = "Aviatrix client id to link account"
}

terraform {
  required_version = ">= 0.11"
  version          = "~1.17"

  # # Remote state info
  # backend "s3" {
  #   # A project specific key
  #   key = "aviatrix/tfstate" # remember to choose unique key for each project

  #   # team shared resources
  #   bucket         = "<tf-state-bucket>"
  #   region         = "ap-southeast-1"
  #   dynamodb_table = "<tf-state-table>"
  #   encrypt        = true
  #   kms_key_id     = "<tf-state-key>"
  # }
}

provider "aws" {
  region  = "${var.region}"
  version = "~> 1.17"
}

data "aws_caller_identity" "current" {}

# # TODO: Aviatrix names are hardcoded, review when updated
# module "aviatrix_label" {
#   source    = "git::ssh://git@bitbucket.org/swatrider/tf-modules.git?ref=master//naming"
#   namespace = "${module.tf_kops_zone_label.namespace}"
#   stage     = "${module.tf_kops_zone_label.stage}"
#   name      = "aviatrix"
# }

locals {
  role_name_prefix = "aviatrix-role"
  approle_name = "${local.role_name_prefix}-app"
  ec2role_name = "${local.role_name_prefix}-ec2"
}

resource "aws_iam_role" "aviatrix_approle" {
  name               = "${local.approle_name}"
  assume_role_policy = "${data.aws_iam_policy_document.aviatrix_approle_trust.json}"
}

resource "aws_iam_role_policy_attachment" "aviatrix_approle" {
  role       = "${aws_iam_role.aviatrix_approle.name}"
  policy_arn = "${aws_iam_policy.aviatrix_approle.arn}"
}

# post the created role info to aviatrix API
resource "null_resource" "aviatrix_api_setup" {
  provisioner "local-exec" {
    command = <<EOT
        curl -s -X POST https://api.aviatrix.io/prod/postiam \
             -H 'Content-Type: application/json' \
             -H 'Authorization: ${var.aviatrix_token}' \
             -d '{"acctId": "${data.aws_caller_identity.current.account_id}","acctGuid": "${var.aviatrix_client_id}","stackName": "Aviatrix-2018-09-02T19-59-36","logGroupName": "","appRoleArn": "${aws_iam_role.aviatrix_approle.arn}"}'
EOT
  }

  # wait for policy attachment resource to be completed first
  depends_on = [
    "aws_iam_role_policy_attachment.aviatrix_approle",
  ]
}

resource "aws_iam_policy" "aviatrix_approle" {
  name        = "${local.approle_name}"
  description = "Aviatrix AWS Integration role"
  policy      = "${data.aws_iam_policy_document.aviatrix_approle.json}"
}

data "aws_iam_policy_document" "aviatrix_approle_trust" {
  statement = {
    principals = {
      type = "AWS"
      identifiers = [
        "arn:aws:iam::${var.aviatrix_account}:root",
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root",
      ]
    }

    actions = [
      "sts:AssumeRole",
    ]
  }
}

# aviatrix approle
data "aws_iam_policy_document" "aviatrix_approle" {
  statement = {
    actions= [
      "ec2:Describe*",
      "elasticloadbalancing:Describe*",
      "route53:List*",
      "route53:Get*",
      "sqs:Get*",
      "sqs:List*",
      "sns:List*",
      "s3:List*",
      "s3:Get*",
      "iam:List*",
      "iam:Get*",
      "directconnect:Describe*",
    ]
    resources = ["*"]
  }
  statement = {
    actions= ["ec2:RunInstances"]
    resources = ["*"]
  }
  statement = {
    actions = ["ec2:RunInstances"]
    resources = ["arn:aws:ec2:*:*:image/ami-*"]
  }
  statement = {
    actions = [
      "ec2:DeleteSecurityGroup",
      "ec2:RevokeSecurityGroupEgress",
      "ec2:RevokeSecurityGroupIngress",
      "ec2:AuthorizeSecurityGroup*",
      "ec2:CreateSecurityGroup",
      "ec2:AssociateRouteTable",
      "ec2:CreateRoute",
      "ec2:CreateRouteTable",
      "ec2:DeleteRoute",
      "ec2:DeleteRouteTable",
      "ec2:DisassociateRouteTable",
      "ec2:ReplaceRoute",
      "ec2:ReplaceRouteTableAssociation",
    ]
    resources = ["*"]
  }
  statement = {
    actions = [
      "ec2:AllocateAddress",
      "ec2:AssociateAddress",
      "ec2:DisassociateAddress",
      "ec2:ReleaseAddress",
      "ec2:AssignPrivateIpAddresses",
      "ec2:AttachNetworkInterface",
      "ec2:CreateNetworkInterface",
      "ec2:DeleteNetworkInterface",
      "ec2:DetachNetworkInterface",
      "ec2:ModifyNetworkInterfaceAttribute",
      "ec2:ResetNetworkInterfaceAttribute",
      "ec2:UnassignPrivateIpAddresses",
      "ec2:ModifyInstanceAttribute",
      "ec2:MonitorInstances",
      "ec2:RebootInstances",
      "ec2:ReportInstanceStatus",
      "ec2:ResetInstanceAttribute",
      "ec2:StartInstances",
      "ec2:StopInstances",
      "ec2:TerminateInstances",
      "ec2:UnmonitorInstances",
      "ec2:AttachInternetGateway",
      "ec2:CreateInternetGateway",
      "ec2:DeleteInternetGateway",
      "ec2:DetachInternetGateway",
      "ec2:CreateKeyPair",
      "ec2:DeleteKeyPair",
      "ec2:CreateSubnet",
      "ec2:DeleteSubnet",
      "ec2:ModifySubnetAttribute",
      "ec2:CreateTags",
      "ec2:DeleteTags",
      "ec2:CreateVpc",
      "ec2:DeleteVpc",
      "ec2:ModifyVpcAttribute",
      "ec2:CreateCustomerGateway",
      "ec2:DeleteCustomerGateway",
      "ec2:CreateVpnConnection",
      "ec2:DeleteVpnConnection",
      "ec2:CreateVpcPeeringConnection",
      "ec2:AcceptVpcPeeringConnection",
      "ec2:DeleteVpcPeeringConnection",
      "ec2:ModifyInstanceCreditSpecification",
    ]
    resources = ["*"]
  }
  statement = {
    actions = [
      "elasticloadbalancing:ApplySecurityGroupsToLoadBalancer",
      "elasticloadbalancing:AttachLoadBalancerToSubnets",
      "elasticloadbalancing:ConfigureHealthCheck",
      "elasticloadbalancing:CreateLoadBalancer*",
      "elasticloadbalancing:DeleteLoadBalancer*",
      "elasticloadbalancing:DeregisterInstancesFromLoadBalancer",
      "elasticloadbalancing:ModifyLoadBalancerAttributes",
      "elasticloadbalancing:SetLoadBalancerPoliciesForBackendServer",
      "elasticloadbalancing:RegisterInstancesWithLoadBalancer",
      "elasticloadbalancing:CreateTargetGroup",
      "elasticloadbalancing:DescribeTargetGroups",
      "elasticloadbalancing:DeleteTargetGroup",
      "elasticloadbalancing:CreateListener",
      "elasticloadbalancing:DescribeListeners",
      "elasticloadbalancing:DeleteListener",
      "elasticloadbalancing:RegisterTargets",
      "elasticloadbalancing:DeregisterTargets"
    ]
    resources = ["*"]
  }
  statement = {
    actions = [
      "route53:ChangeResourceRecordSets",
      "route53:CreateHostedZone",
      "route53:DeleteHostedZone",
    ]
    resources = ["*"]
  }
  statement = {
    actions = [
      "s3:CreateBucket",
      "s3:DeleteBucket",
      "s3:PutObject",
      "s3:DeleteObject",
    ]
    resources = ["*"]
  }
  statement = {
    actions = [
      "sqs:AddPermission",
      "sqs:ChangeMessageVisibility",
      "sqs:CreateQueue",
      "sqs:DeleteMessage",
      "sqs:DeleteQueue",
      "sqs:PurgeQueue",
      "sqs:ReceiveMessage",
      "sqs:RemovePermission",
      "sqs:SendMessage",
      "sqs:SetQueueAttributes",
      "sqs:TagQueue",
    ]
    resources = ["*"]
  }
  statement = {
    actions = ["sts:AssumeRole"]
    resources = ["arn:aws:iam::*"]
  }
  statement = {
    actions = [
      "iam:PassRole",
      "iam:AddRoleToInstanceProfile",
      "iam:CreateInstanceProfile",
      "iam:DeleteInstanceProfile",
      "iam:RemoveRoleFromInstanceProfile"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role" "aviatrix_ec2role" {
  name               = "${local.ec2role_name}"
  assume_role_policy = "${data.aws_iam_policy_document.aviatrix_ec2role_trust.json}"
}

resource "aws_iam_role_policy_attachment" "aviatrix_ec2role" {
  role       = "${aws_iam_role.aviatrix_ec2role.name}"
  policy_arn = "${aws_iam_policy.aviatrix_ec2role.arn}"
}

resource "aws_iam_policy" "aviatrix_ec2role" {
  name        = "${local.ec2role_name}"
  description = "Aviatrix AWS Integration EC2 role"
  policy      = "${data.aws_iam_policy_document.aviatrix_ec2role.json}"
}

data "aws_iam_policy_document" "aviatrix_ec2role_trust" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

# aviatrix EC2role
data "aws_iam_policy_document" "aviatrix_ec2role" {
  statement = {
    actions = [
        "aws-marketplace:MeterUsage"
    ]
    resources = ["*"]
  }
  statement = {
    actions = [
        "sts:AssumeRole",
    ]
    resources = ["arn:aws:iam::*:role/${local.role_name_prefix}-*"]
  }
}

output "aviatrix_approle_arn" {
  description = "Arn for the Aviatrix approle"
  value       = "${aws_iam_role.aviatrix_approle.arn}"
}

output "aviatrix_ec2role_arn" {
  description = "Arn for the Aviatrix ec2role"
  value       = "${aws_iam_role.aviatrix_ec2role.arn}"
}
