locals {
  services_to_activate = [
    "run.googleapis.com",
    "workflows.googleapis.com",
    "cloudscheduler.googleapis.com",
    "iamcredentials.googleapis.com",
    "storage-component.googleapis.com",
    "cloudbuild.googleapis.com",
    "vpcaccess.googleapis.com"
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
    "roles/actions.Admin",
    "roles/storage.admin",
    "roles/iam.serviceAccountUser",
    "roles/cloudbuild.builds.editor",
    "roles/viewer",
    "roles/secretmanager.secretAccessor"
  ]
  image = var.image == null ? "${var.region}-docker.pkg.dev/${var.project_id}/${var.project_name}/${var.project_name}-function:latest" : var.image

  local_vpc_connector = var.ip_fixe ? {
    ip_cidr_range = "10.10.10.0/28"
    vpc_self_link = google_compute_network.vpc_network[0].self_link
    name          = "vpc-connector-${var.project_name}"
    } : var.enable_vpn ? {
    ip_cidr_range = "10.10.10.0/28"
    name          = "vpc-connector"
    network       = "vpc-${var.project_id}"
  } : null

  revision_annotations = var.ip_fixe ? {
    vpcaccess = {
      egress    = "ALL_TRAFFIC"
      vpcaccess = "vpc-connector-${var.project_name}"
    }
  } : null

  job_url = "https://${var.region}.googleapis.com/apis/run.googleapis.com/v1/namespaces/${var.project_id}/jobs/cloudrun-${var.project_name}-${var.project_id}:run"
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
  lifecycle {
    ignore_changes = [
      lifecycle_rule,
    ]
  }
}

resource "google_storage_bucket" "bucket_cloudbuild" {
  count                       = try(var.create_job ? 1 : 0, 0)
  project                     = var.project_id
  name                        = "${var.project_id}_cloudbuild"
  location                    = var.region
  storage_class               = "REGIONAL"
  uniform_bucket_level_access = true
  lifecycle {
    ignore_changes = [
      lifecycle_rule,
    ]
  }
}

####
# Activate services api
####

resource "google_project_service" "service" {
  for_each                   = toset(local.services_to_activate)
  project                    = var.project_id
  service                    = each.value
  disable_on_destroy         = false
  disable_dependent_services = false
}

####
# Cloud run
####

module "google_cloud_run" {
  source          = "git::https://github.com/GoogleCloudPlatform/cloud-foundation-fabric//modules/cloud-run-v2?ref=v34.1.0"
  project_id      = var.project_id
  name            = "cloudrun-${var.project_name}-${var.project_id}"
  region          = var.region
  ingress         = var.create_job ? null : var.ingress_settings
  service_account = google_service_account.service_account.email

  create_job = var.create_job

  containers = {
    "${var.project_name}" = {
      image = local.image
      resources = {
        limits = {
          memory = var.memory_limits
          cpu    = var.cpu_limits
        }
      }
      env          = var.env
      env_from_key = var.env_from_key
    }
  }
  vpc_connector_create = local.local_vpc_connector
  revision             = local.revision_annotations

  depends_on = [
    google_project_service.service,
    github_repository.function-repo
  ]

}

####
# Workflow
####
resource "google_workflows_workflow" "workflow" {
  count           = try(var.schedule == null || var.create_job ? 0 : 1, 0)
  name            = "workflow-${var.project_name}-${var.project_id}"
  region          = var.region
  project         = var.project_id
  description     = "A workflow for ${var.project_id} data transfert"
  service_account = google_service_account.service_account.id
  source_contents = <<-EOF
  - cdf-function:
        call: http.get
        args:
            url: ${var.create_job ? local.job_url : module.google_cloud_run.service.status[0].url}
            auth:
                type: OIDC
            timeout: 1800
        result: function_result
EOF
  depends_on      = [google_project_service.service]
}

data "google_project" "project" {
  project_id = var.project_id
}

resource "google_cloud_scheduler_job" "job" {
  count            = try(var.schedule == null ? 0 : 1, 0)
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
    uri = var.create_job ? "https://${var.region}-run.googleapis.com/apis/run.googleapis.com/v1/namespaces/${data.google_project.project.number}/jobs/${var.project_name}:run" : "https://workflowexecutions.googleapis.com/v1/${one(google_workflows_workflow.workflow[*].id)}/executions"

  }
  depends_on = [google_project_service.service, google_workflows_workflow.workflow]
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

#---------------------------------------------------------
# github
#---------------------------------------------------------

# github repo
#----------------------------------

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
  archive_on_destroy = true
}


# projet de changement du nom de la fonction par terraform, mais finalement je pense que ça ne devrait pas être ici car c'est un sujet ponctuel qui ne doit pas etre re traité à chaque exécution.
# data "github_repository_file" "main_py" {
#   repository = github_repository.function-repo.name
#   branch     = "main"
#   file       = "main.py"
# }

# resource "github_repository_file" "main_py_replace" {
#   repository          = github_repository.function-repo.name
#   file                = "main.py"
#   content             = replace(data.github_repository_file.main_py.content, "$${APPLICATION}", replace(var.project_name, "-", "_"))
#   commit_message      = "fix: nom de l'appli dans main.py"
#   overwrite_on_create = true
#   # dependances pour que le contexte du wf qui se déclenche suite au commit puisse finir son build
#   depends_on = [
#     # 
#     # github_actions_variable.function_name_variable,
#     github_actions_variable.gcp_repository_secret,
#     github_actions_variable.gcp_cloud_service_secret
#   ]

#   lifecycle {
#     create_before_destroy = true
#     ignore_changes = [content]
#   }
# }

resource "github_repository_collaborator" "maintainer" {
  count = var.maintainers == null ? 0 : length(var.maintainers)

  repository = github_repository.function-repo.name
  username   = var.maintainers[count.index]
  permission = "maintain"
}

# github action
#----------------------------------
resource "google_service_account_key" "service_account_key" {
  service_account_id = google_service_account.service_account.name
}

resource "github_actions_secret" "gcp_credentials_secret" {
  repository      = github_repository.function-repo.name
  secret_name     = "GCP_CREDENTIALS"
  plaintext_value = google_service_account_key.service_account_key.private_key
}

resource "github_actions_variable" "gcp_region_secret" {
  repository    = github_repository.function-repo.name
  variable_name = "GCP_REGION"
  value         = var.region
}

resource "github_actions_variable" "gcp_projecy_id_secret" {
  repository    = github_repository.function-repo.name
  variable_name = "GCP_PROJECT_ID"
  value         = var.project_id
}

resource "github_actions_variable" "gcp_repository_secret" {
  repository    = github_repository.function-repo.name
  variable_name = "GCP_REPOSITORY"
  value         = google_artifact_registry_repository.project-repo.name
}

resource "github_actions_variable" "gcp_service_account_variable" {
  repository    = github_repository.function-repo.name
  variable_name = "GCP_SERVICE_ACCOUNT"
  value         = google_service_account.service_account.email
}

resource "github_actions_variable" "gcp_cloud_service_secret" {
  # count         = try(var.create_job ? 0 : 1, 0)
  repository    = github_repository.function-repo.name
  variable_name = "GCP_CLOUD_SERVICE"
  value         = module.google_cloud_run[0].service_name
}

resource "github_actions_variable" "project_name" {
  repository    = github_repository.function-repo.name
  variable_name = "PROJECT_NAME"
  value         = var.project_name
}

resource "github_actions_variable" "function_name_variable" {
  repository    = github_repository.function-repo.name
  variable_name = "FUNCTION_NAME"
  value         = replace(var.project_name, "-", "_")
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
      filter = "severity=ERROR ${var.create_job ? "" : "AND resource.labels.service_name = " + module.google_cloud_run.service_name}"
    }
  }

  notification_channels = var.notification_channels
  alert_strategy {
    notification_rate_limit {
      period = "300s"
    }
    auto_close = "86400s" # 1 jour
  }
}

###############################
# ip fixe publique
###############################
#  Activation des API
resource "google_project_service" "service_compute" {
  count   = try(var.ip_fixe ? 1 : 0, 0)
  service = "compute.googleapis.com"
}

resource "google_project_service" "service_vpcaccess" {
  count   = try(var.ip_fixe ? 1 : 0, 0)
  service = "vpcaccess.googleapis.com"
}

resource "google_compute_network" "vpc_network" {
  count                   = try(var.ip_fixe ? 1 : 0, 0)
  name                    = "cloud-run-vpc-network"
  auto_create_subnetworks = true
  depends_on              = [google_project_service.service_compute, google_project_service.service_vpcaccess]
}

resource "google_compute_address" "default" {
  count      = try(var.ip_fixe ? 1 : 0, 0)
  name       = "cr-static-ip-addr"
  depends_on = [google_project_service.service_compute, google_project_service.service_vpcaccess]
}

resource "google_compute_router" "compute_router" {
  count   = try(var.ip_fixe ? 1 : 0, 0)
  name    = "cr-static-ip-router"
  network = google_compute_network.vpc_network[0].name
  region  = var.region
}

resource "google_compute_router_nat" "default" {
  count  = try(var.ip_fixe ? 1 : 0, 0)
  name   = "cr-static-nat-${var.project_name}"
  router = google_compute_router.compute_router[0].name
  region = var.region

  nat_ip_allocate_option = "MANUAL_ONLY"
  nat_ips                = [google_compute_address.default[0].self_link]

  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}
