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
  description = "Image Cloud Run à déployer"
  default     = null
}

variable "group_name" {
  type        = string
  description = "Google groupe associé au projet"
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
  type        = map(any)
  default     = null
}

variable "ingress_settings" {
  description = "Ingress settings can be one of 'all', 'internal', 'internal-and-cloud-load-balancing'(default)."
  type        = string
  default     = "internal-and-cloud-load-balancing"
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
