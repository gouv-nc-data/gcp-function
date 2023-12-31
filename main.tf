locals {
  group_role = "roles/editor"
  services_to_activate = [
    "run.googleapis.com",
    "workflows.googleapis.com",
    "cloudscheduler.googleapis.com",
    "iamcredentials.googleapis.com",
    "storage-component.googleapis.com"
  ]
  service_account_roles = ["roles/bigquery.dataEditor",
    "roles/bigquery.user",
    "roles/storage.objectAdmin",
    "roles/storagetransfer.user",
    "roles/run.admin",
    "roles/iam.serviceAccountUser",
    "roles/iam.workloadIdentityUser",
    "roles/artifactregistry.admin",
    "roles/workflows.invoker",
    "roles/storage.objectUser",
    "roles/storage.insightsCollectorService",
  ]
  image = var.image == null ? "${var.region}-docker.pkg.dev/${var.project_id}/${var.project_name}/${var.project_name}-function:latest" : var.image
}

resource "google_service_account" "service_account" {
  account_id   = "sa-${var.project_name}"
  display_name = "Service Account created by terraform for ${var.project_id}"
  project      = var.project_id
}

resource "google_project_iam_member" "service_account_bindings" {
  for_each = toset(local.service_account_roles)
  project  = var.project_id
  role     = each.value
  member   = "serviceAccount:${google_service_account.service_account.email}"
}

####
# Bucket
####

resource "google_storage_bucket" "bucket" {
  count                       = try(var.create_bucket ? 1 : 0, 0)
  project                     = var.project_id
  name                        = "bucket-${var.project_name}-${var.project_id}"
  location                    = var.region
  storage_class               = "REGIONAL"
  uniform_bucket_level_access = true
}

####
# Activate services api
####

resource "google_project_service" "service" {
  for_each = toset(local.services_to_activate)
  project  = var.project_id
  service  = each.value
}

####
# Cloud run
####

module "google_cloud_run" {
  source           = "git::https://github.com/GoogleCloudPlatform/cloud-foundation-fabric//modules/cloud-run?ref=v26.0.0"
  project_id       = var.project_id
  name             = "cloudrun-${var.project_name}-${var.project_id}"
  region           = var.region
  ingress_settings = "internal-and-cloud-load-balancing"
  service_account  = google_service_account.service_account.email

  containers = {
    "${var.project_name}" = {
      image = local.image
      resources = {
        limits = {
          memory = var.memory_limits
          cpu    = var.cpu_limits
        }
      }
      env = var.env
    }
  }
  depends_on      = [google_project_service.service]
  timeout_seconds = var.timeout_seconds
}

####
# Workflow
####
resource "google_workflows_workflow" "workflow" {
  name            = "workflow-${var.project_name}-${var.project_id}"
  region          = var.region
  project         = var.project_id
  description     = "A workflow for ${var.project_id} data transfert"
  service_account = google_service_account.service_account.id
  source_contents = <<-EOF
  - cdf-function:
        call: http.get
        args:
            url: ${module.google_cloud_run.service.status[0].url}
            auth:
                type: OIDC
            timeout: 1800
        result: function_result
EOF
  depends_on      = [google_project_service.service]
}

resource "google_cloud_scheduler_job" "job" {
  name             = "schedule-${var.project_name}-${var.project_id}"
  project          = var.project_id
  description      = "Schedule du workflow pour ${var.project_name} en ${var.schedule}]"
  schedule         = var.schedule
  time_zone        = "Pacific/Noumea"
  attempt_deadline = "320s"
  region           = var.region

  retry_config {
    retry_count = 1
  }

  http_target {
    http_method = "POST"
    oauth_token {
      service_account_email = google_service_account.service_account.email
    }
    uri = "https://workflowexecutions.googleapis.com/v1/${google_workflows_workflow.workflow.id}/executions"

  }
  depends_on = [google_project_service.service]
}

####
# Artifact registry
####
resource "google_artifact_registry_repository" "project-repo" {
  project       = var.project_id
  location      = var.region
  repository_id = var.project_name
  description   = "docker repository for ${var.project_name}"
  format        = "DOCKER"
  depends_on    = [google_project_service.service]
}

resource "google_artifact_registry_repository_iam_member" "binding" {
  project    = var.project_id
  location   = var.region
  repository = google_artifact_registry_repository.project-repo.name
  role       = "roles/artifactregistry.repoAdmin"
  member     = "serviceAccount:${google_service_account.service_account.email}"
}

####
# repo github
####

terraform {
  required_providers {
    github = {
      source = "integrations/github"
    }
  }
}

resource "github_repository" "function-repo" {
  name        = "${var.direction}-${var.project_name}-function"
  description = "Dépot pour le projet ${var.project_name} de la direction ${var.direction}"

  visibility = "internal"

  template {
    owner                = "gouv-nc-data"
    repository           = "gcp-function-template"
    include_all_branches = false
  }
}

resource "google_service_account_key" "service_account_key" {
  service_account_id = google_service_account.service_account.name
}

resource "github_actions_secret" "gcp_credentials_secret" {
  repository      = github_repository.function-repo.name
  secret_name     = "GCP_CREDENTIALS"
  plaintext_value = google_service_account_key.service_account_key.private_key
  depends_on = [github_repository.function-repo,
  google_service_account_key.service_account_key]
}

resource "github_actions_variable" "gcp_region_secret" {
  repository    = github_repository.function-repo.name
  variable_name = "GCP_REGION"
  value         = var.region
  depends_on    = [github_repository.function-repo]
}

resource "github_actions_variable" "gcp_projecy_id_secret" {
  repository    = github_repository.function-repo.name
  variable_name = "GCP_PROJECT_ID"
  value         = var.project_id
  depends_on    = [github_repository.function-repo]
}

resource "github_actions_variable" "gcp_repository_secret" {
  repository    = github_repository.function-repo.name
  variable_name = "GCP_REPOSITORY"
  value         = google_artifact_registry_repository.project-repo.name
  depends_on    = [github_repository.function-repo]
}

resource "github_actions_variable" "gcp_cloud_service_secret" {
  repository    = github_repository.function-repo.name
  variable_name = "GCP_CLOUD_SERVICE"
  value         = module.google_cloud_run.service_name
  depends_on    = [github_repository.function-repo]
}

resource "github_actions_variable" "project_name" {
  repository    = github_repository.function-repo.name
  variable_name = "PROJECT_NAME"
  value         = var.project_name
  depends_on    = [github_repository.function-repo]
}

resource "github_actions_variable" "function_name_variable" {
  repository    = github_repository.function-repo.name
  variable_name = "FUNCTION_NAME"
  value         = replace(var.project_name, "-", "_")
  depends_on    = [github_repository.function-repo]
}

###############################
# Supervision
###############################
resource "google_monitoring_alert_policy" "errors" {
  display_name = "Errors in logs alert policy on ${var.project_name}"
  project      = var.project_id
  combiner     = "OR"
  conditions {
    display_name = "Error condition"
    condition_matched_log {
      filter = "severity=ERROR AND resource.labels.service_name = ${module.google_cloud_run.service_name}"
    }
  }

  notification_channels = var.notification_channels
  alert_strategy {
    notification_rate_limit {
      period = "300s"
    }
  }
}
