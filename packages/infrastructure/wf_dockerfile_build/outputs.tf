output "arguments" {
  description = "The arguments to the WorkflowTemplate"
  value       = module.image_builder_workflow.arguments
}

output "aws_role_name" {
  description = "The name of the AWS role used by the Workflow's Service Account"
  value       = module.image_builder_workflow.aws_role_name
}

output "aws_role_arn" {
  description = "The name of the AWS role used by the Workflow's Service Account"
  value       = module.image_builder_workflow.aws_role_arn
}

output "name" {
  description = "The name of the WorkflowTemplate"
  value       = var.name
}

output "entrypoint" {
  description = "The name of the first template in the Workflow"
  value       = local.entrypoint
}
