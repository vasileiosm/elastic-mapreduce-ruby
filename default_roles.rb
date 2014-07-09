#
# Copyright 2011-2013 Amazon.com, Inc. or its affiliates.  All Rights Reserved.

module DefaultRoles

  EC2_ROLE_NAME = "EMR_EC2_DefaultRole"
  EMR_ROLE_NAME = "EMR_DefaultRole"

  def self.assume_role_policy(serviceprincipal)
    return %/{
      "Version":"2008-10-17",
      "Statement": [
        {
          "Sid":"",
          "Effect":"Allow",
          "Principal": { "Service": "#{serviceprincipal}" },
          "Action":"sts:AssumeRole"
        }
      ]
    }/
  end

  EC2_ROLE_POLICY = %/{
    "Statement": [
      {
       "Action": [
         "cloudwatch:*",
         "dynamodb:*",
         "ec2:Describe*",
         "elasticmapreduce:Describe*",
         "rds:Describe*",
         "s3:*",
         "sdb:*",
         "sns:*",
         "sqs:*"
       ],
       "Effect": "Allow",
       "Resource": [ "*" ]
      }
    ]
  }/

  EMR_ROLE_POLICY = %/{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Action": [
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:CancelSpotInstanceRequests",
          "ec2:CreateSecurityGroup",
          "ec2:CreateTags",
          "ec2:Describe*",
          "ec2:DeleteTags",
          "ec2:ModifyImageAttribute",
          "ec2:ModifyInstanceAttribute",
          "ec2:RequestSpotInstances",
          "ec2:RunInstances",
          "ec2:TerminateInstances",
          "iam:PassRole",
          "iam:ListRolePolicies",
          "iam:GetRole",
          "iam:GetRolePolicy",
          "iam:ListInstanceProfiles",
          "s3:Get*",
          "s3:List*",
          "s3:CreateBucket",
          "sdb:BatchPutAttributes",
          "sdb:Select"
        ],
        "Effect": "Allow",
        "Resource": "*"
      }
    ]
  }/

end
