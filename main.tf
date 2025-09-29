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
    "roles/secretmanager.secretAccessor",
    "roles/logging.logWriter",
  ]
  image                 = var.image == null ? "${var.region}-docker.pkg.dev/${var.project_id}/${var.project_name}/${var.project_name}-function:${var.image_tag}" : var.image
  image_project_id      = var.image == null ? var.project_id : split("/", var.image)[1]
  image_repository_name = var.image == null ? var.project_name : split("/", var.image)[2]

  local_vpc_connector = var.ip_fixe ? {
    ip_cidr_range = "10.10.10.0/28"
    vpc_self_link = google_compute_network.vpc_network[0].self_link
    name          = "vpc-connector-${var.project_name}"
    network       = "cloud-run-vpc-network"
    } : var.enable_vpn ? {
    ip_cidr_range = "10.10.10.0/28"
    name          = "vpc-connector"
    network       = "vpc-${var.project_id}"
  } : null

  revision_annotations = var.ip_fixe ? {
    vpc_access = {
      egress    = "ALL_TRAFFIC"
      connector = "vpc-connector-${var.project_name}" # a tester
    }
    # job = {
    #   max_retries = 0 # pas défini dans la 34.1
    # }
    } : {
    # job = {
    #   max_retries = 0 # pas défini dans la 34.1
    # }
  }
  create_job       = var.type == "JOB" ? true : false
  gh_repo_template = local.create_job ? "gcp-cloud-run-job-template" : "gcp-cloud-run-service-template"
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
  count = try(var.create_bucket ? 1 : 0, 0)

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

####
# Activate services api
####

resource "google_project_service" "service" {
  for_each = toset(local.services_to_activate)

  project                    = var.project_id
  service                    = each.value
  disable_on_destroy         = false
  disable_dependent_services = false
}

####
# Cloud run
####

module "google_cloud_run" {
  source          = "git::https://github.com/GoogleCloudPlatform/cloud-foundation-fabric//modules/cloud-run-v2?ref=v44.1.0"
  project_id      = var.project_id
  name            = "cloudrun-${var.project_name}-${var.project_id}"
  region          = var.region
  service_account = google_service_account.service_account.email

  type = var.type

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

  job_config     = var.job_config
  service_config = local.create_job ? null : var.service_config

  depends_on = [
    google_project_service.service,
    github_repository.function-repo[0]
  ]
}

# for project number
data "google_project" "project" {
  project_id = var.project_id
}

resource "google_cloud_scheduler_job" "schedule_job_or_svc" {
  count = try(var.schedule == null ? 0 : 1, 0)

  provider         = google-beta # indiqué dans la doc
  name             = "schedule-${var.project_name}-${var.project_id}"
  project          = var.project_id
  description      = "Schedule du ${local.create_job ? "job" : "service"} pour ${var.project_name} en ${var.schedule}]"
  schedule         = var.schedule
  time_zone        = "Pacific/Noumea"
  attempt_deadline = "320s"
  region           = var.region

  retry_config {
    retry_count = 1
  }

  http_target {
    http_method = local.create_job ? "POST" : "GET"
    uri         = local.create_job ? "https://${var.region}-run.googleapis.com/apis/run.googleapis.com/v1/namespaces/${data.google_project.project.number}/jobs/${module.google_cloud_run.job.name}:run" : "https://cloudrun-${var.project_name}-${var.project_id}-${data.google_project.project.number}.${var.region}.run.app"

    dynamic "oauth_token" {
      for_each = local.create_job ? [1] : []
      content {
        service_account_email = google_service_account.service_account.email
      }
    }

    dynamic "oidc_token" {
      for_each = local.create_job ? [] : [1]
      content {
        service_account_email = google_service_account.service_account.email
      }
    }
  }

  depends_on = [google_project_service.service]
}

####
# Artifact registry
####
resource "google_artifact_registry_repository" "project-repo" {
  count = var.image == null ? 1 : 0

  project       = var.project_id
  location      = var.region
  repository_id = var.project_name
  description   = "docker repository for ${var.project_name}"
  format        = "DOCKER"
  depends_on    = [google_project_service.service]
}

resource "google_artifact_registry_repository_iam_member" "binding" {
  project    = local.image_project_id
  location   = var.region
  repository = var.image == null ? google_artifact_registry_repository.project-repo[0].name : local.image_repository_name
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
  count = var.image == null ? 1 : 0

  name        = "${var.direction}-${var.project_name}-function"
  description = "Dépot pour le projet ${var.project_name} de la direction ${var.direction}"

  visibility = "internal"

  template {
    owner                = "gouv-nc-data"
    repository           = local.gh_repo_template
    include_all_branches = false
  }
  archive_on_destroy = true
}

resource "github_repository_collaborator" "maintainer" {
  count = var.maintainers == null || var.image != null ? 0 : length(var.maintainers)

  repository = github_repository.function-repo[0].name
  username   = var.maintainers[count.index] # pas de mail
  permission = "maintain"
}

# github action
#----------------------------------
resource "google_service_account_key" "service_account_key" {
  count = var.image == null ? 1 : 0

  service_account_id = google_service_account.service_account.name
}

resource "github_actions_secret" "gcp_credentials_secret" {
  count = var.image == null ? 1 : 0

  repository      = github_repository.function-repo[0].name
  secret_name     = "GCP_CREDENTIALS"
  plaintext_value = google_service_account_key.service_account_key.private_key
}

resource "github_actions_variable" "gcp_region_secret" {
  count = var.image == null ? 1 : 0

  repository    = github_repository.function-repo[0].name
  variable_name = "GCP_REGION"
  value         = var.region
}

resource "github_actions_variable" "gcp_project_id_secret" {
  count = var.image == null ? 1 : 0

  repository    = github_repository.function-repo[0].name
  variable_name = "GCP_PROJECT_ID"
  value         = var.project_id
}

resource "github_actions_variable" "gcp_repository_secret" {
  count = var.image == null ? 1 : 0

  repository    = github_repository.function-repo[0].name
  variable_name = "GCP_REPOSITORY"
  value         = google_artifact_registry_repository.project-repo[0].name
}

resource "github_actions_variable" "gcp_service_account_variable" {
  count = var.image == null ? 1 : 0

  repository    = github_repository.function-repo[0].name
  variable_name = "GCP_SERVICE_ACCOUNT"
  value         = google_service_account.service_account.email
}

resource "github_actions_variable" "gcp_cloud_service_secret" {
  count = try(local.create_job || var.image != null ? 0 : 1, 0)

  repository    = github_repository.function-repo[0].name
  variable_name = "GCP_CR_SVC_NAME"
  value         = "cloudrun-${var.project_name}-${var.project_id}" # module.google_cloud_run.service_name est dependant du module et celui ci dépend de l'image qui dépend de GCP_CR_SVC_NAME
}

resource "github_actions_variable" "gcp_cr_job_name" {
  count = try(local.create_job && var.image == null ? 1 : 0, 1)

  repository    = github_repository.function-repo[0].name
  variable_name = "GCP_CR_JOB_NAME"
  value         = "cloudrun-${var.project_name}-${var.project_id}" # module.google_cloud_run.job.name est dependant du module
}

resource "github_actions_variable" "project_name" {
  count = var.image == null ? 1 : 0

  repository    = github_repository.function-repo[0].name
  variable_name = "PROJECT_NAME"
  value         = var.project_name
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
      filter = "severity=ERROR ${local.create_job ? format("resource.labels.job_name=%s", module.google_cloud_run.job.name) : format("resource.labels.service_name=%s", module.google_cloud_run.service_name)}"
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
