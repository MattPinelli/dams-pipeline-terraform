variable "image" {
  default     = "hashicorp/terraform"
  description = "The image identifier of the Terraform Docker image to use for the pipeline."
}

variable "plan_buildspec" {
  description = "The build spec declaration path to use for this build project's terraform plan builds."
  default     = ".buildspec/plan.yml"
}

variable "apply_buildspec" {
  description = "The build spec declaration path to use for this build project's terraform apply builds."
  default     = ".buildspec/apply.yml"
}

variable "artifacts_store" {
  description = "The S3 bucket where AWS CodePipeline stores artifacts for the pipeline."
  default     = "dev-toolmon-dams-artifacts"
}

variable "name" {
  description = "The name of the pipeline."
  default     = "dams-deploy"
}

variable "bucket_arn" {
  description = "The ARN of the artifacts bucket."
  default     = "arn:aws:s3:::dev-toolmon-dams-artifacts"
}

variable "build_timeout" {
  description = "How long in minutes, from 5 to 480 (8 hours), for AWS CodeBuild to wait until timing out any related build that does not get marked as completed. The default is 30 minutes."
  default     = "30"
}

variable "compute_type" {
  description = "Information about the compute resources the build project will use."
  default     = "BUILD_GENERAL1_SMALL"
}

variable "owner" {
  description = "The organization of the Github repository."
  default     = "Argus"
}

variable "branch" {
  description = "The branch to pull changes from."
  default     = "master"
}

variable "account_name" {
  description = "name of the AWS account"
  default     = "dev-toolmon"
}

variable "aws_region" {
  description = "AWS Region"
  default     = "us-east-1"
}
