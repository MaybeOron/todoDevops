variable "github_owner" {
  type        = string
  default     = "MaybeOron"
  description = "github owner"
}

variable "github_token" {
  type        = string
  default     = "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"
  description = "github token"
}


variable "flux_repo" {
  default     = "git@github.com:MaybeOron/todoFlux"
  description = "flux repo link"
}

variable "kube_config_path" {
  default     = "/home/ubuntu/.kube/config"
  description = "kube config full path"
}

variable "region" {
  default     = "eu-west-2"
  description = "AWS region"
}

variable "cluster_name" {
  default = "oron-portfolio-eks"
  description = "AWS cluster name"
}

# variable "map_accounts" {
#   description = "Additional AWS account numbers to add to the aws-auth configmap."
#   type        = list(string)

#   default = [
#     "777777777777",
#     "888888888888",
#   ]
# }

# variable "map_roles" {
#   description = "Additional IAM roles to add to the aws-auth configmap."
#   type = list(object({
#     rolearn  = string
#     username = string
#     groups   = list(string)
#   }))

#   default = [
#     {
#       rolearn  = "arn:aws:iam::66666666666:role/role1"
#       username = "role1"
#       groups   = ["system:masters"]
#     },
#   ]
# }

# variable "map_users" {
#   description = "Additional IAM users to add to the aws-auth configmap."
#   type = list(object({
#     userarn  = string
#     username = string
#     groups   = list(string)
#   }))

#   default = [
#     {
#       userarn  = "arn:aws:iam::66666666666:user/user1"
#       username = "user1"
#       groups   = ["system:masters"]
#     },
#     {
#       userarn  = "arn:aws:iam::66666666666:user/user2"
#       username = "user2"
#       groups   = ["system:masters"]
#     },
#   ]
# }