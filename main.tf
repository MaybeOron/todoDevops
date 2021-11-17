terraform {
  required_version = ">= 0.13"
}

provider "aws" {
  version = ">= 3.14.1"
  region  = var.region
}

data "aws_eks_cluster" "cluster" {
  name = module.eks.cluster_id
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_id
}

data "aws_availability_zones" "available" {
}

resource "aws_security_group" "worker_group_mgmt_one" {
  name_prefix = "worker_group_mgmt_one"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port = 22
    to_port   = 22
    protocol  = "tcp"

    cidr_blocks = [
      "10.0.0.0/8",
    ]
  }
}

resource "aws_security_group" "all_worker_mgmt" {
  name_prefix = "all_worker_management"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port = 22
    to_port   = 22
    protocol  = "tcp"

    cidr_blocks = [
      "10.0.0.0/8",
      "172.16.0.0/12",
      "192.168.0.0/16",
    ]
  }
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "2.6.0"

  name                 = "test-vpc"
  cidr                 = "10.0.0.0/16"
  azs                  = data.aws_availability_zones.available.names
  private_subnets      = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets       = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true

  public_subnet_tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                      = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"             = "1"
  }
}

module "eks" {
  source       = "terraform-aws-modules/eks/aws"
  cluster_name    = var.cluster_name
  cluster_version = "1.20"
  subnets         = module.vpc.private_subnets
  version = "12.2.0"
  cluster_create_timeout = "1h"
  cluster_endpoint_private_access = true 

  vpc_id = module.vpc.vpc_id

  worker_groups = [
    {
      name                          = "worker-group-1"
      instance_type                 = "t2.small"
      additional_userdata           = "echo foo bar"
      asg_desired_capacity          = 3
      additional_security_group_ids = [aws_security_group.worker_group_mgmt_one.id]
    },
    {
      name                          = "worker-group-2"
      instance_type                 = "t2.small"
      additional_userdata           = "echo foo bar"
      asg_desired_capacity          = 3
      additional_security_group_ids = [aws_security_group.worker_group_mgmt_one.id]
    }
  ]

  worker_additional_security_group_ids = [aws_security_group.all_worker_mgmt.id]
  map_roles                            = var.map_roles
  map_users                            = var.map_users
  map_accounts                         = var.map_accounts
}



provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
  token                  = data.aws_eks_cluster_auth.cluster.token
  load_config_file       = false
  version                = "~> 1.11"
}

provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}


# resource "helm_release" "ingress-nginx" {
#   name       = "ingress-nginx"

#   repository = "https://kubernetes.github.io/ingress-nginx"
#   chart      = "ingress-nginx"
#     namespace = "ingress-nginx"
#     create_namespace = true
# }



resource "helm_release" "kube-prometheus-stack" {
  name       = "kube-prometheus-stack"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  namespace = "kube-monitoring"
  create_namespace = true
  values = [<<EOF

  EOF
  ]
}


resource "helm_release" "kibana" {
  name       = "kibana"
  repository = "https://helm.elastic.co"
  chart      = "kibana"
  namespace = "kube-logging"
  create_namespace = true
  values = [<<EOF
  imageTag: "7.15.0"
  replicas: 1
  resources:
  requests:
    cpu: "400m"
    memory: "0.5Gi"
  limits:
    cpu: "400m"
    memory: "0.5Gi"
  EOF
  ]
}

resource "helm_release" "elasticsearch" {
  name       = "elasticsearch"
  repository = "https://helm.elastic.co"
  chart      = "elasticsearch"
  namespace = "kube-logging"
  create_namespace = true
  values = [<<EOF
  imageTag: "7.15.0"
  replicas: 3
  minimumMasterNodes: 1
  resources:
  requests:
    cpu: "250m"
    memory: "1.0Gi"
  limits:
    cpu: "500m"
    memory: "1.0Gi"
  EOF
  ]
}

resource "helm_release" "fluentd" {
  name       = "fluentd"

  repository = "https://fluent.github.io/helm-charts"
  chart      = "fluentd"
  namespace = "kube-logging"
  create_namespace = true

  values = [<<EOF
  fileConfigs:
    01_sources.conf: |-
      <source>
        @id fluentd-containers.log
        @type tail
        path /var/log/containers/*.log
        pos_file /var/log/containers.log.pos
        tag raw.kubernetes.*
        read_from_head true
        <parse>
          @type multi_format
          <pattern>
            format json
            time_key time
            time_format %Y-%m-%dT%H:%M:%S.%NZ
          </pattern>
          <pattern>
            format /^(?<time>.+) (?<stream>stdout|stderr) [^ ]* (?<log>.*)$/
            time_format %Y-%m-%dT%H:%M:%S.%N%:z
          </pattern>
        </parse>
      </source>

    02_filters.conf: |-
      # Detect exceptions in the log output and forward them as one log entry.
      <match raw.kubernetes.**>
        @id raw.kubernetes
        @type detect_exceptions
        remove_tag_prefix raw
        message log
        stream stream
        multiline_flush_interval 5
        max_bytes 500000
        max_lines 1000
      </match>

      # Concatenate multi-line logs
      <filter **>
        @id filter_concat
        @type concat
        key message
        multiline_end_regexp /\n$/
        separator ""
        timeout_label @NORMAL
        flush_interval 5
      </filter>

      # Enriches records with Kubernetes metadata
      <filter kubernetes.**>
        @id filter_kubernetes_metadata
        @type kubernetes_metadata
      </filter>

      # Fixes json fields in Elasticsearch
      <filter kubernetes.**>
        @id filter_parser
        @type parser
        key_name log
        reserve_time true
        reserve_data true
        remove_key_name_field true
        <parse>
          @type multi_format
          <pattern>
            format json
          </pattern>
          <pattern>
            format none
          </pattern>
        </parse>
      </filter>

    03_dispatch.conf: |-

    04_outputs.conf: |-
      # handle timeout log lines from concat plugin
      <match **>
        @type relabel
        @label @NORMAL
      </match>

      <label @NORMAL>
      <match **>
        @id elasticsearch
        @type elasticsearch
        @log_level info
        include_tag_key true
        host "elasticsearch-master"
        port 9200
        path ""
        scheme http
        ssl_verify true
        ssl_version TLSv1_2
        type_name _doc
        logstash_format true
        logstash_prefix logstash
        reconnect_on_error true
        <buffer>
          @type file
          path /var/log/fluentd-buffers/kubernetes.system.buffer
          flush_mode interval
          retry_type exponential_backoff
          flush_thread_count 2
          flush_interval 5s
          retry_forever
          retry_max_interval 30
          chunk_limit_size 2M
          queue_limit_length 8
          overflow_action block
        </buffer>
      </match>
      </label>

  EOF
  ]

}