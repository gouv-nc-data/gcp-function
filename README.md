Module terraform de création de ressources Google Cloud Function pour injection de données dans BigQuery

# Ressources créées
* Compte de service avec les bons rôles
* Bucket de transfert intermédiaire
* Dataset BigQuery
* TODO: Cloud Function V2
<!-- BEGIN_TF_DOCS -->
## Requirements

No requirements.

## Providers

| Name | Version |
|------|---------|
| <a name="provider_github"></a> [github](#provider\_github) | n/a |
| <a name="provider_google"></a> [google](#provider\_google) | n/a |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_google_cloud_run"></a> [google\_cloud\_run](#module\_google\_cloud\_run) | git::https://github.com/GoogleCloudPlatform/cloud-foundation-fabric//modules/cloud-run | v26.0.0 |

## Resources

| Name | Type |
|------|------|
| [github_actions_secret.gcp_cloud_service_secret](https://registry.terraform.io/providers/integrations/github/latest/docs/resources/actions_secret) | resource |
| [github_actions_secret.gcp_credentials_secret](https://registry.terraform.io/providers/integrations/github/latest/docs/resources/actions_secret) | resource |
| [github_actions_secret.gcp_projecy_id_secret](https://registry.terraform.io/providers/integrations/github/latest/docs/resources/actions_secret) | resource |
| [github_actions_secret.gcp_region_secret](https://registry.terraform.io/providers/integrations/github/latest/docs/resources/actions_secret) | resource |
| [github_actions_secret.gcp_repository_secret](https://registry.terraform.io/providers/integrations/github/latest/docs/resources/actions_secret) | resource |
| [github_actions_secret.project_name](https://registry.terraform.io/providers/integrations/github/latest/docs/resources/actions_secret) | resource |
| [github_repository.function-repo](https://registry.terraform.io/providers/integrations/github/latest/docs/resources/repository) | resource |
| [google_artifact_registry_repository.project-repo](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/artifact_registry_repository) | resource |
| [google_artifact_registry_repository_iam_member.binding](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/artifact_registry_repository_iam_member) | resource |
| [google_cloud_scheduler_job.job](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/cloud_scheduler_job) | resource |
| [google_project_iam_member.service_account_bindings](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_service.service](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_service) | resource |
| [google_service_account.service_account](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account) | resource |
| [google_service_account_key.service_account_key](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account_key) | resource |
| [google_storage_bucket.bucket](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket) | resource |
| [google_workflows_workflow.workflow](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/workflows_workflow) | resource |

Le service account créé est de la forme `sa-${var.project_name}` et doit matcher : `^[a-z](?:[-a-z0-9]***4,28***[a-z0-9])$`

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_create_bucket"></a> [create\_bucket](#input\_create\_bucket) | Création ou non d'un bucket associé au projet | `bool` | `true` | no |
| <a name="input_direction"></a> [direction](#input\_direction) | direction du projet | `string` | n/a | yes |
| <a name="input_function_runtime"></a> [function\_runtime](#input\_function\_runtime) | Runtime associé à la google cloud function | `string` | `"python311"` | no |
| <a name="input_group_name"></a> [group\_name](#input\_group\_name) | Google groupe associé au projet | `string` | n/a | yes |
| <a name="input_image"></a> [image](#input\_image) | Image Cloud Run à déployer | `string` | `null` | no |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | id du projet | `string` | n/a | yes |
| <a name="input_project_name"></a> [project\_name](#input\_project\_name) | nom du projet | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | n/a | `string` | `"europe-west1"` | no |
| <a name="input_schedule"></a> [schedule](#input\_schedule) | expression cron de schedule du job | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_run_url"></a> [run\_url](#output\_run\_url) | n/a |
<!-- END_TF_DOCS -->