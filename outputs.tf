output "name" {
  description = "The name of the pipeline."
  value       = "${aws_codepipeline.pipeline.name}"
}

output "apply_project_id" {
  description = "The ARN of the CodeBuild project responsible for `terraform plan`."
  value       = "${aws_codebuild_project.apply.id}"
}

output "plan_project_id" {
  description = "The ARN of the CodeBuild project responsible for `terraform apply`."
  value       = "${aws_codebuild_project.plan.id}"
}

output "build_role_id" {
  value = "${aws_iam_role.codebuild.id}"
}
