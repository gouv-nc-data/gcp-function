variable "project_id" {
  type        = string
  description = "id du projet"
}

variable "project_name" {
  type        = string
  description = "nom du projet"
}

variable "direction" {
  type        = string
  description = "direction du projet"
}

variable "region" {
  type    = string
  default = "europe-west1"
}

variable "create_bucket" {
  type        = bool
  default     = true
  description = "Création ou non d'un bucket associé au projet"
}

variable "function_runtime" {
  type        = string
  default     = "python311"
  description = "Runtime associé à la google cloud function"
}

variable "image" {
  type        = string
  description = "Image Cloud Run à déployer, si présent les ressources github ne sont pas créées"
  default     = null
}

variable "image_tag" {
  type        = string
  description = "Tag de l'image Cloud Run à déployer"
  default     = "latest"
}

# depreciated : not used in the code, kept for compatibility. To rm in next major release
variable "group_name" {
  type        = string
  description = "Google groupe associé au projet"
  default     = null
}

variable "schedule" {
  type        = string
  description = "expression cron de schedule du job"
  default     = null
}

variable "timeout_seconds" {
  type        = number
  description = "timeout d'execution de la fonction"
  default     = 300
}

variable "notification_channels" {
  type        = list(string)
  description = "canal de notification pour les alertes sur cloud run"
}

variable "memory_limits" {
  type        = string
  default     = "512Mi"
  description = "Mémoire maximale allouée au container https://cloud.google.com/run/docs/configuring/memory-limits?hl=fr#terraform"
}

variable "cpu_limits" {
  type        = string
  default     = "1000m"
  description = "cpu maximal alloué au container https://cloud.google.com/run/docs/configuring/cpu?hl=fr"
}

variable "env" {
  description = "Variables d'environnement pour Cloud Run"
  type        = map(string)
  default     = null
}

variable "env_from_key" {
  description = "Variables venant de secret d'environnement pour Cloud Run. La valeur est une map où la clé est le nom du secret."
  type        = map(object({
    secret_name  = string
    version = optional(string, "latest")
  }))
  default     = {}
}

variable "ip_fixe" {
  description = "Setup an ip fix for the function"
  type        = bool
  default     = false
}

variable "maintainers" {
  description = "List of maintainers for the GH repo"
  type        = list(string)
  default     = null
}

# variable "create_job" {
#   description = "Deploiement en mode service ou job (par défaut)"
#   type        = bool
#   default     = "true"
# }

variable "type" {
  description = "Deploiement en mode service ou job (par défaut)"
  type        = string
  default     = "JOB" #JOB, SERVICE or WORKERPOOL
}

variable "enable_vpn" {
  description = "Lance le job dans le subnet qui accède au vpn"
  type        = bool
  default     = "false"
}

variable "vpn_network" {
  description = "Nom du VPC spoke pour la connexion VPN (requis si enable_vpn = true)"
  type        = string
  default     = null
  validation {
    condition     = var.enable_vpn == false || var.vpn_network != null
    error_message = "La variable vpn_network doit être définie quand enable_vpn est true."
  }
}

variable "job_config" {
  description = "Cloud Run Job specific configuration."
  type = object({
    max_retries = optional(number)
    task_count  = optional(number)
    timeout     = optional(string)
  })
  default  = {}
  nullable = false
  validation {
    condition     = var.job_config.timeout == null ? true : endswith(var.job_config.timeout, "s")
    error_message = "Timeout should follow format of number with up to nine fractional digits, ending with 's'. Example: '3.5s'."
  }
}

variable "service_config" {
  description = "Cloud Run service specific configuration options."
  type = object({
    custom_audiences = optional(list(string), null)
    eventarc_triggers = optional(
      object({
        audit_log = optional(map(object({
          method  = string
          service = string
        })))
        pubsub = optional(map(string))
        storage = optional(map(object({
          bucket = string
          path   = optional(string)
        })))
        service_account_email = optional(string)
    }), {})
    gen2_execution_environment = optional(bool, false)
    iap_config = optional(object({
      iam          = optional(list(string), [])
      iam_additive = optional(list(string), [])
    }), null)
    ingress              = optional(string, null) # ["INGRESS_TRAFFIC_ALL", "INGRESS_TRAFFIC_INTERNAL_ONLY","INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER"]
    invoker_iam_disabled = optional(bool, false)
    max_concurrency      = optional(number)
    scaling = optional(object({
      max_instance_count = optional(number)
      min_instance_count = optional(number)
    }))
    timeout = optional(string)
  })
  default  = {}
  nullable = false
}

variable "external_secret_project_id" {
  description = "ID du projet contenant les secrets externes. Requis si env_from_key est utilisé."
  type        = string
  default     = "prj-dinum-p-secret-mgnt-aaf4"
}

