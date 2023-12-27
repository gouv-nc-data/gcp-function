#!/usr/bin/env python
from constructs import Construct
from cdktf import VariableType, TerraformVariable, Fn, Token, TerraformOutput
#
# Provider bindings are generated by running `cdktf get`.
# See https://cdk.tf/provider-generation for more details.
#
from imports.github.actions_secret import ActionsSecret
from imports.github.actions_variable import ActionsVariable
from imports.github.repository import Repository
from imports.google.artifact_registry_repository import ArtifactRegistryRepository
from imports.google.artifact_registry_repository_iam_member import ArtifactRegistryRepositoryIamMember
from imports.google.cloud_scheduler_job import CloudSchedulerJob
from imports.google.monitoring_alert_policy import MonitoringAlertPolicy
from imports.google.project_iam_member import ProjectIamMember
from imports.google.project_service import ProjectService
from imports.google.service_account import ServiceAccount
from imports.google.service_account_key import ServiceAccountKey
from imports.google.storage_bucket import StorageBucket
from imports.google.workflows_workflow import WorkflowsWorkflow
from imports import google_cloud_run as gcr


class GcpFunction(Construct):
    def __init__(self, scope, name):
        super().__init__(scope, name)
        # Terraform Variables are not always the best fit for getting inputs in the context of Terraform CDK.
        #     You can read more about this at https://cdk.tf/variables
        cpu_limits = TerraformVariable(self, "cpu_limits",
                                       default="1000m",
                                       description="cpu maximal alloué au container https://cloud.google.com/run/docs/configuring/cpu?hl=fr",
                                       type=VariableType.STRING
                                       )
        create_bucket = TerraformVariable(self, "create_bucket",
                                          default=True,
                                          description="Création ou non d'un bucket associé au projet",
                                          type=VariableType.BOOL
                                          )
        direction = TerraformVariable(self, "direction",
                                      description="direction du projet",
                                      type=VariableType.STRING
                                      )
        env = TerraformVariable(self, "env",
                                default=None,
                                description="Variables d'environnement pour Cloud Run",
                                type=VariableType.map(VariableType.ANY)
                                )
        image = TerraformVariable(self, "image",
                                  default=None,
                                  description="Image Cloud Run à déployer",
                                  type=VariableType.STRING
                                  )
        memory_limits = TerraformVariable(self, "memory_limits",
                                          default="512Mi",
                                          description="Mémoire maximale allouée au container https://cloud.google.com/run/docs/configuring/memory-limits?hl=fr#terraform",
                                          type=VariableType.STRING
                                          )
        notification_channels = TerraformVariable(self, "notification_channels",
                                                  description="canal de notification pour les alertes sur cloud run",
                                                  type=VariableType.list(VariableType.STRING)
                                                  )
        project_id = TerraformVariable(self, "project_id",
                                       description="id du projet",
                                       type=VariableType.STRING
                                       )
        project_name = TerraformVariable(self, "project_name",
                                         description="nom du projet",
                                         type=VariableType.STRING
                                         )
        region = TerraformVariable(self, "region",
                                   default="europe-west1",
                                   type=VariableType.STRING
                                   )
        schedule = TerraformVariable(self, "schedule",
                                     description="expression cron de schedule du job",
                                     type=VariableType.STRING
                                     )
        timeout_seconds = TerraformVariable(self, "timeout_seconds",
                                            default=300,
                                            description="timeout d'execution de la fonction",
                                            type=VariableType.NUMBER
                                            )

        if image.value is None:
            local_image = "${" + region.value + "}-docker.pkg.dev/${" + project_id.value + "}/${" + project_name.value + "}/${" + project_name.value + "}-function:latest"
        else:
            local_image = image.value

        service_account_roles = ["roles/bigquery.dataEditor", "roles/bigquery.user", "roles/storage.objectAdmin",
                                 "roles/storagetransfer.user", "roles/run.admin", "roles/iam.serviceAccountUser",
                                 "roles/iam.workloadIdentityUser", "roles/artifactregistry.admin",
                                 "roles/workflows.invoker", "roles/storage.objectUser",
                                 "roles/storage.insightsCollectorService"
                                 ]
        services_to_activate = ["run.googleapis.com", "workflows.googleapis.com", "cloudscheduler.googleapis.com",
                                "iamcredentials.googleapis.com", "storage-component.googleapis.com"
                                ]

        function_repo = Repository(self, "function-repo",
                                   description="Dépot pour le projet ${" + project_name.value + "} de la direction ${" + direction.value + "}",
                                   name="${" + direction.value + "}-${" + project_name.value + "}-function",
                                   template={
                                       "include_all_branches": False,
                                       "owner": "gouv-nc-data",
                                       "repository": "gcp-function-template"
                                   },
                                   visibility="internal"
                                   )

        for svc in services_to_activate:
            service = ProjectService(self, "service",
                                     project=project_id.string_value,
                                     service=Token.as_string(svc),
                                     )

        service_account = ServiceAccount(self, "service_account",
                                         account_id="sa-${" + project_name.value + "}",
                                         display_name="Service Account created by terraform for ${" + project_id.value + "}",
                                         project=project_id.string_value
                                         )

        service_account_key = ServiceAccountKey(self, "service_account_key",
                                                service_account_id=service_account.name
                                                )

        # Création du bucket seulement si demandé
        if create_bucket.value:
            StorageBucket(self, "bucket",
                          location=region.string_value,
                          name="bucket-${" + project_name.value + "}-${" + project_id.value + "}",
                          project=project_id.string_value,
                          storage_class="REGIONAL",
                          uniform_bucket_level_access=True,
                          )

        google_cloud_run = gcr.GoogleCloudRun(self, "google_cloud_run",
                                              containers=[{
                                                  "${var.project_name}": [{
                                                      "env": env.value,
                                                      "image": local_image,
                                                      "resources": [{
                                                          "limits": [{
                                                              "cpu": cpu_limits.value,
                                                              "memory": memory_limits.value
                                                          }
                                                          ]
                                                      }
                                                      ]
                                                  }
                                                  ]
                                              }
                                              ],
                                              depends_on=[service],
                                              ingress_settings="internal-and-cloud-load-balancing",
                                              name="cloudrun-${" + project_name.value + "}-${" + project_id.value + "}",
                                              project_id=project_id.value,
                                              region=region.value,
                                              service_account=service_account.email,
                                              timeout_seconds=timeout_seconds.value
                                              )
        ActionsSecret(self, "gcp_credentials_secret",
                      depends_on=[function_repo, service_account_key],
                      plaintext_value=service_account_key.private_key,
                      repository=function_repo.name,
                      secret_name="GCP_CREDENTIALS"
                      )
        ActionsVariable(self, "function_name_variable",
                        depends_on=[function_repo],
                        repository=function_repo.name,
                        value=Token.as_string(Fn.replace(project_name.string_value, "-", "_")),
                        variable_name="FUNCTION_NAME"
                        )
        ActionsVariable(self, "gcp_cloud_service_secret",
                        depends_on=[function_repo],
                        repository=function_repo.name,
                        value=Token.as_string(google_cloud_run.service_name_output),
                        variable_name="GCP_CLOUD_SERVICE"
                        )
        ActionsVariable(self, "gcp_projecy_id_secret",
                        depends_on=[function_repo],
                        repository=function_repo.name,
                        value=project_id.string_value,
                        variable_name="GCP_PROJECT_ID"
                        )
        ActionsVariable(self, "gcp_region_secret",
                        depends_on=[function_repo],
                        repository=function_repo.name,
                        value=region.string_value,
                        variable_name="GCP_REGION"
                        )
        github_actions_variable_project_name = ActionsVariable(self, "project_name_23",
                                                               depends_on=[function_repo],
                                                               repository=function_repo.name,
                                                               value=project_name.string_value,
                                                               variable_name="PROJECT_NAME"
                                                               )
        # This allows the Terraform resource name to match the original name. You can remove the call if you don't need them to match.
        github_actions_variable_project_name.override_logical_id("project_name")
        project_repo = ArtifactRegistryRepository(self, "project-repo",
                                                  depends_on=[service],
                                                  description="docker repository for ${" + project_name.value + "}",
                                                  format="DOCKER",
                                                  location=region.string_value,
                                                  project=project_id.string_value,
                                                  repository_id=project_name.string_value
                                                  )
        ArtifactRegistryRepositoryIamMember(self, "binding",
                                            location=region.string_value,
                                            member="serviceAccount:${" + service_account.email + "}",
                                            project=project_id.string_value,
                                            repository=project_repo.name,
                                            role="roles/artifactregistry.repoAdmin"
                                            )

        MonitoringAlertPolicy(self, "errors",
                              alert_strategy={
                                  "notification_rate_limit": {
                                      "period": "300s"
                                  }
                              },
                              combiner="OR",
                              conditions=[{
                                  "condition_matched_log": {
                                      "filter": "severity=ERROR AND resource.labels.service_name = ${" + google_cloud_run.service_name_output + "}"
                                  },
                                  "display_name": "Error condition"
                              }
                              ],
                              display_name="Errors in logs alert policy on ${" + project_name.value + "}",
                              notification_channels=notification_channels.list_value,
                              project=project_id.string_value
                              )

        for sar in service_account_roles:
            ProjectIamMember(self, "service_account_bindings",
                             member="serviceAccount:${" + service_account.email + "}",
                             project=project_id.string_value,
                             role=Token.as_string(sar),
                             )

        workflow = WorkflowsWorkflow(self, "workflow",
                                     depends_on=[service],
                                     description="A workflow for ${" + project_id.value + "} data transfert",
                                     name="workflow-${" + project_name.value + "}-${" + project_id.value + "}",
                                     project=project_id.string_value,
                                     region=region.string_value,
                                     service_account=service_account.id,
                                     source_contents="- cdf-function:\n      call: http.get\n      args:\n          url: " +
                                                     Token.as_string(
                                                         Fn.lookup_nested(google_cloud_run.service_output.status, ["0",
                                                                                                                   "url"])) + "\n          auth:\n              type: OIDC\n          timeout: 1800\n      result: function_result\n\n"
                                     )

        ActionsVariable(self, "gcp_repository_secret",
                        depends_on=[function_repo],
                        repository=function_repo.name,
                        value=project_repo.name,
                        variable_name="GCP_REPOSITORY"
                        )
        CloudSchedulerJob(self, "job",
                          attempt_deadline="320s",
                          depends_on=[service],
                          description="Schedule du workflow pour ${" + project_name.value + "} en ${" + schedule.value + "}]",
                          http_target={
                              "http_method": "POST",
                              "oauth_token": {
                                  "service_account_email": service_account.email
                              },
                              "uri": "https://workflowexecutions.googleapis.com/v1/${" + workflow.id + "}/executions"
                          },
                          name="schedule-${" + project_name.value + "}-${" + project_id.value + "}",
                          project=project_id.string_value,
                          region=region.string_value,
                          retry_config={
                              "retry_count": 1
                          },
                          schedule=schedule.string_value,
                          time_zone="Pacific/Noumea"
                          )

        TerraformOutput(self, "run_url",
                        value=Fn.lookup_nested(google_cloud_run.service_output.status, ["0", "url"])
                        )