variable "server_name" {
  type        = string
  description = "Unique hostname tag mapped to the virtualization resource node."
}

variable "cpus" {
  type        = number
  description = "Core processor units assigned allocation metric."
}

variable "memory" {
  type        = string
  description = "System RAM boundary envelope capacity limit mapping."
}
