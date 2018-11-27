resource "aws_codecommit_repository" "dams" {
  repository_name = "${var.account_name}-dams"
  description     = "DAMS repository in AWS"
  default_branch  = "master"
}

# SNS
resource "aws_sns_topic" "dams_approval_topic" {
  name         = "${var.account_name}-DAMS-Approval"
  display_name = "${var.account_name}-DAMS-Approval"

  provisioner "local-exec" {
    command = "aws sns subscribe --topic-arn ${self.arn} --protocol email --notification-endpoint matt.pinelli@d2l.com --region ${var.aws_region}"
  }

  provisioner "local-exec" {
    command = "aws sns subscribe --topic-arn ${self.arn} --protocol email --notification-endpoint andrew.alkema@d2l.com --region ${var.aws_region}"
  }

  provisioner "local-exec" {
    command = "aws sns subscribe --topic-arn ${self.arn} --protocol email --notification-endpoint jeff.haroutunian@d2l.com --region ${var.aws_region}"
  }

  provisioner "local-exec" {
    command = "aws sns subscribe --topic-arn ${self.arn} --protocol email --notification-endpoint alex.ivan@d2l.com --region ${var.aws_region}"
  }
}

#Create trigger for Code Commit Repo
resource "aws_cloudwatch_event_rule" "repo-notification" {
  depends_on  = ["aws_codecommit_repository.dams"]
  name        = "${var.account_name}-dams-pipeline-trigger"
  description = "Initiate pipeline when code is pushed"

  event_pattern = <<PATTERN
{
  "source": [ "aws.codecommit" ],
  "detail-type": [ "CodeCommit Repository State Change" ],
  "resources": [ "${aws_codecommit_repository.dams.arn}" ],
  "detail": {
     "event": [
       "referenceCreated",
       "referenceUpdated"],
     "referenceType":["branch"],
     "referenceName": ["master"]
  }
}
PATTERN
}

# Set target for the trigger
resource "aws_cloudwatch_event_target" "repo-notification-target" {
  rule     = "${aws_cloudwatch_event_rule.repo-notification.name}"
  arn      = "${aws_codepipeline.pipeline.arn}"
  role_arn = "${aws_iam_role.codepipeline.arn}"
}

resource "aws_codebuild_project" "plan" {
  name          = "${var.name}-plan"
  description   = "Defines an environment for planning the execution of terraform scripts."
  service_role  = "${aws_iam_role.codebuild.arn}"
  build_timeout = "${var.build_timeout}"

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type = "${var.compute_type}"
    image        = "${var.image}"
    type         = "LINUX_CONTAINER"

    environment_variable {
      "name"  = "TF_IN_AUTOMATION"
      "value" = "true"
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = "${var.plan_buildspec}"
  }
}

resource "aws_codebuild_project" "apply" {
  name          = "${var.name}-apply"
  description   = "Defines an environment for executing a terraform plan."
  service_role  = "${aws_iam_role.codebuild.arn}"
  build_timeout = "${var.build_timeout}"

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type = "${var.compute_type}"
    image        = "${var.image}"
    type         = "LINUX_CONTAINER"

    environment_variable {
      "name"  = "TF_IN_AUTOMATION"
      "value" = "true"
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = "${var.apply_buildspec}"
  }
}

resource "aws_codepipeline" "pipeline" {
  name     = "${var.name}"
  role_arn = "${aws_iam_role.codepipeline.arn}"

  artifact_store = {
    location = "${var.artifacts_store}"
    type     = "S3"
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeCommit"
      version          = "1"
      output_artifacts = ["source"]

      configuration {
        PollForSourceChanges = true
        RepositoryName       = "${aws_codecommit_repository.dams.repository_name}"
        BranchName           = "master"
      }
    }
  }

  stage {
    name = "Plan"

    action {
      name             = "Plan"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["source"]
      output_artifacts = ["plan"]

      configuration {
        ProjectName = "${aws_codebuild_project.plan.name}"
      }
    }
  }

  stage {
    name = "Approve"

    action {
      name     = "Approval"
      category = "Approval"
      owner    = "AWS"
      provider = "Manual"
      version  = "1"

      configuration {
        NotificationArn = "${aws_sns_topic.dams_approval_topic.arn}"
        CustomData      = "Review the output from `terraform plan` in the Plan stage logs. CTRL-F 'Terraform Plan'."
      }
    }
  }

  stage {
    name = "Apply"

    action {
      name             = "Apply"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["source", "plan"]
      output_artifacts = []

      configuration {
        ProjectName   = "${aws_codebuild_project.apply.name}"
        PrimarySource = "source"
      }
    }
  }
}

###
### IAM Service Roles
###

resource "aws_iam_role" "codebuild" {
  name               = "${var.name}-codebuild"
  description        = "Allows CodeBuild to access resources necessary for Terraform Pipelines."
  assume_role_policy = "${data.aws_iam_policy_document.codebuild_assume_policy.json}"
}

data "aws_iam_policy_document" "codebuild_assume_policy" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["codebuild.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "codepipeline" {
  name               = "${var.name}-codepipeline"
  description        = "Allows CodePipeline to access resources necessary for Terraform Pipelines."
  assume_role_policy = "${data.aws_iam_policy_document.codepipeline_assume_policy.json}"
}

data "aws_iam_policy_document" "codepipeline_assume_policy" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["codepipeline.amazonaws.com"]
    }
  }
}

###
### IAM Minimal Policies
###

data "aws_iam_policy_document" "codebuild" {
  statement {
    effect = "Allow"

    actions = [
      "codebuild:ListBuildsForProject",
      "codebuild:BatchGetBuilds",
      "codebuild:BatchGetProjects",
      "codebuild:BatchDeleteBuilds",
      "codebuild:CreateProject",
      "codebuild:DeleteProject",
      "codebuild:StartBuild",
      "codebuild:StopBuild",
      "codebuild:UpdateProject",
    ]

    resources = ["${aws_codebuild_project.apply.id}", "${aws_codebuild_project.plan.id}"]
  }

  statement {
    effect = "Allow"

    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]

    resources = ["*"]
  }

  statement {
    effect = "Allow"

    actions = [
      "elasticbeanstalk:*",
      "ec2:*",
      "elasticloadbalancing:*",
      "autoscaling:*",
      "cloudwatch:*",
      "s3:*",
      "sns:*",
      "cloudformation:*",
      "rds:*",
      "sqs:*",
      "ecs:*",
      "iam:*",
      "codecommit:*",
    ]

    resources = ["*"]
  }
}

data "aws_iam_policy_document" "codepipeline" {
  statement {
    effect = "Allow"

    actions = [
      "codebuild:BatchGetBuilds",
      "codebuild:StartBuild",
    ]

    resources = ["${aws_codebuild_project.apply.id}", "${aws_codebuild_project.plan.id}"]
  }

  statement {
    effect = "Allow"

    actions = [
      "elasticbeanstalk:*",
      "ec2:*",
      "elasticloadbalancing:*",
      "autoscaling:*",
      "cloudwatch:*",
      "s3:*",
      "sns:*",
      "cloudformation:*",
      "rds:*",
      "sqs:*",
      "ecs:*",
      "iam:*",
      "codecommit:*",
    ]

    resources = ["*"]
  }
}

data "aws_iam_policy_document" "artifacts" {
  statement {
    effect = "Allow"

    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:GetBucketVersioning",
      "s3:PutObject",
    ]

    resources = [
      "${var.bucket_arn}",
      "${var.bucket_arn}/*",
    ]
  }
}

##
## IAM Policy
##

resource "aws_iam_role_policy" "attach_artifacts" {
  name_prefix = "${var.name}-artifacts-"
  role        = "${aws_iam_role.codebuild.id}"
  policy      = "${data.aws_iam_policy_document.artifacts.json}"
}

resource "aws_iam_role_policy" "attach_codebuild" {
  name_prefix = "${var.name}-codebuild-"
  role        = "${aws_iam_role.codebuild.id}"
  policy      = "${data.aws_iam_policy_document.codebuild.json}"
}

resource "aws_iam_role_policy" "attach_codepipeline" {
  name_prefix = "${var.name}-codepipeline-"
  role        = "${aws_iam_role.codepipeline.id}"
  policy      = "${data.aws_iam_policy_document.codepipeline.json}"
}
