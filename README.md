Module terraform de création de ressources Google Cloud Function pour injection de données dans BigQuery

# Ressources créées
* Compte de service avec les bons rôles
* Bucket de transfert intermédiaire
* Dataset BigQuery
* TODO: Cloud Function V2

Le service account créé est de la forme `sa-${var.project_name}` et doit matcher : `^[a-z](?:[-a-z0-9]***4,28***[a-z0-9])$`

<!-- BEGIN_TF_DOCS -->
## Requirements

No requirements.

## Providers

| Name | Version |
|------|---------|
| <a name="provider_github"></a> [github](#provider\_github) | 6.3.1 |
| <a name="provider_google"></a> [google](#provider\_google) | 5.44.2 |
| <a name="provider_google-beta"></a> [google-beta](#provider\_google-beta) | 5.44.2 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_google_cloud_run"></a> [google\_cloud\_run](#module\_google\_cloud\_run) | git::https://github.com/GoogleCloudPlatform/cloud-foundation-fabric//modules/cloud-run-v2 | v44.1.0 |

## Resources

| Name | Type |
|------|------|
| [github_actions_secret.gcp_credentials_secret](https://registry.terraform.io/providers/integrations/github/latest/docs/resources/actions_secret) | resource |
| [github_actions_variable.gcp_cloud_service_secret](https://registry.terraform.io/providers/integrations/github/latest/docs/resources/actions_variable) | resource |
| [github_actions_variable.gcp_cr_job_name](https://registry.terraform.io/providers/integrations/github/latest/docs/resources/actions_variable) | resource |
| [github_actions_variable.gcp_projecy_id_secret](https://registry.terraform.io/providers/integrations/github/latest/docs/resources/actions_variable) | resource |
| [github_actions_variable.gcp_region_secret](https://registry.terraform.io/providers/integrations/github/latest/docs/resources/actions_variable) | resource |
| [github_actions_variable.gcp_repository_secret](https://registry.terraform.io/providers/integrations/github/latest/docs/resources/actions_variable) | resource |
| [github_actions_variable.gcp_service_account_variable](https://registry.terraform.io/providers/integrations/github/latest/docs/resources/actions_variable) | resource |
| [github_actions_variable.project_name](https://registry.terraform.io/providers/integrations/github/latest/docs/resources/actions_variable) | resource |
| [github_repository.function-repo](https://registry.terraform.io/providers/integrations/github/latest/docs/resources/repository) | resource |
| [github_repository_collaborator.maintainer](https://registry.terraform.io/providers/integrations/github/latest/docs/resources/repository_collaborator) | resource |
| [google-beta_google_cloud_scheduler_job.schedule_job_or_svc](https://registry.terraform.io/providers/hashicorp/google-beta/latest/docs/resources/google_cloud_scheduler_job) | resource |
| [google_artifact_registry_repository.project-repo](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/artifact_registry_repository) | resource |
| [google_artifact_registry_repository_iam_member.binding](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/artifact_registry_repository_iam_member) | resource |
| [google_compute_address.default](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_address) | resource |
| [google_compute_network.vpc_network](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_network) | resource |
| [google_compute_router.compute_router](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_router) | resource |
| [google_compute_router_nat.default](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_router_nat) | resource |
| [google_monitoring_alert_policy.errors](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/monitoring_alert_policy) | resource |
| [google_project_iam_member.service_account_bindings](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_service.service](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_service) | resource |
| [google_project_service.service_compute](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_service) | resource |
| [google_project_service.service_vpcaccess](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_service) | resource |
| [google_service_account.service_account](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account) | resource |
| [google_service_account_key.service_account_key](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account_key) | resource |
| [google_storage_bucket.bucket](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket) | resource |
| [google_project.project](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/project) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_cpu_limits"></a> [cpu\_limits](#input\_cpu\_limits) | cpu maximal alloué au container https://cloud.google.com/run/docs/configuring/cpu?hl=fr | `string` | `"1000m"` | no |
| <a name="input_create_bucket"></a> [create\_bucket](#input\_create\_bucket) | Création ou non d'un bucket associé au projet | `bool` | `true` | no |
| <a name="input_create_job"></a> [create\_job](#input\_create\_job) | Deploiement en mode service ou job (par défaut) | `bool` | `"true"` | no |
| <a name="input_direction"></a> [direction](#input\_direction) | direction du projet | `string` | n/a | yes |
| <a name="input_enable_vpn"></a> [enable\_vpn](#input\_enable\_vpn) | Lance le job dans le subnet qui accède au vpn | `bool` | `"false"` | no |
| <a name="input_env"></a> [env](#input\_env) | Variables d'environnement pour Cloud Run | `map(string)` | `null` | no |
| <a name="input_env_from_key"></a> [env\_from\_key](#input\_env\_from\_key) | Variables venant de secret d'environnement pour Cloud Run | `map(any)` | `null` | no |
| <a name="input_eventarc_triggers"></a> [eventarc\_triggers](#input\_eventarc\_triggers) | Trigger eventarc | <pre>object({<br/>    audit_log = optional(map(object({<br/>      method  = string<br/>      service = string<br/>    })))<br/>    pubsub                 = optional(map(string))<br/>    service_account_email  = optional(string)<br/>    service_account_create = optional(bool, false)<br/>  })</pre> | `{}` | no |
| <a name="input_function_runtime"></a> [function\_runtime](#input\_function\_runtime) | Runtime associé à la google cloud function | `string` | `"python311"` | no |
| <a name="input_group_name"></a> [group\_name](#input\_group\_name) | Google groupe associé au projet | `string` | `null` | no |
| <a name="input_image"></a> [image](#input\_image) | Image Cloud Run à déployer | `string` | `null` | no |
| <a name="input_ingress_settings"></a> [ingress\_settings](#input\_ingress\_settings) | Ingress settings can be one of ['INGRESS\_TRAFFIC\_ALL', 'INGRESS\_TRAFFIC\_INTERNAL\_ONLY', 'INGRESS\_TRAFFIC\_INTERNAL\_LOAD\_BALANCER'] | `string` | `"INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER"` | no |
| <a name="input_ip_fixe"></a> [ip\_fixe](#input\_ip\_fixe) | Setup an ip fix for the function | `bool` | `false` | no |
| <a name="input_job_config"></a> [job\_config](#input\_job\_config) | Cloud Run Job specific configuration. | <pre>object({<br/>    max_retries = optional(number)<br/>    task_count  = optional(number)<br/>    timeout     = optional(string)<br/>  })</pre> | `{}` | no |
| <a name="input_maintainers"></a> [maintainers](#input\_maintainers) | List of maintainers for the GH repo | `list(string)` | `null` | no |
| <a name="input_memory_limits"></a> [memory\_limits](#input\_memory\_limits) | Mémoire maximale allouée au container https://cloud.google.com/run/docs/configuring/memory-limits?hl=fr#terraform | `string` | `"512Mi"` | no |
| <a name="input_notification_channels"></a> [notification\_channels](#input\_notification\_channels) | canal de notification pour les alertes sur cloud run | `list(string)` | n/a | yes |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | id du projet | `string` | n/a | yes |
| <a name="input_project_name"></a> [project\_name](#input\_project\_name) | nom du projet | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | n/a | `string` | `"europe-west1"` | no |
| <a name="input_schedule"></a> [schedule](#input\_schedule) | expression cron de schedule du job | `string` | `null` | no |
| <a name="input_timeout_seconds"></a> [timeout\_seconds](#input\_timeout\_seconds) | timeout d'execution de la fonction | `number` | `300` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_function_name"></a> [function\_name](#output\_function\_name) | n/a |
| <a name="output_function_sa_email"></a> [function\_sa\_email](#output\_function\_sa\_email) | n/a |
| <a name="output_ip"></a> [ip](#output\_ip) | n/a |
| <a name="output_run_url"></a> [run\_url](#output\_run\_url) | n/a |
| <a name="output_vpc_network_name"></a> [vpc\_network\_name](#output\_vpc\_network\_name) | n/a |
<!-- END_TF_DOCS -->