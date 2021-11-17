
# # resource "helm_release" "ingress-nginx" {
# #   name       = "ingress-nginx"

# #   repository = "https://kubernetes.github.io/ingress-nginx"
# #   chart      = "ingress-nginx"
#     # namespace = "ingress-nginx"
#     # create_namespace = true
# # }



# resource "helm_release" "kube-prometheus-stack" {
#   name       = "kube-prometheus-stack"
#   repository = "https://prometheus-community.github.io/helm-charts"
#   chart      = "kube-prometheus-stack"
#   namespace = "kube-monitoring"
#   create_namespace = true
#   values = [<<EOF

#   EOF
#   ]
# }


# resource "helm_release" "kibana" {
#   name       = "kibana"
#   repository = "https://helm.elastic.co"
#   chart      = "kibana"
#   namespace = "kube-logging"
#   create_namespace = true
#   values = [<<EOF
#   imageTag: "7.15.0"
#   replicas: 1
#   resources:
#   requests:
#     cpu: "400m"
#     memory: "0.5Gi"
#   limits:
#     cpu: "400m"
#     memory: "0.5Gi"
#   EOF
#   ]
# }

# resource "helm_release" "elasticsearch" {
#   name       = "elasticsearch"
#   repository = "https://helm.elastic.co"
#   chart      = "elasticsearch"
#   namespace = "kube-logging"
#   create_namespace = true
#   values = [<<EOF
#   imageTag: "7.15.0"
#   replicas: 3
#   minimumMasterNodes: 1
#   resources:
#   requests:
#     cpu: "250m"
#     memory: "1.0Gi"
#   limits:
#     cpu: "500m"
#     memory: "1.0Gi"
#   EOF
#   ]
# }

# resource "helm_release" "fluentd" {
#   name       = "fluentd"

#   repository = "https://fluent.github.io/helm-charts"
#   chart      = "fluentd"
#   namespace = "kube-logging"
#   create_namespace = true

#   values = [<<EOF
#   fileConfigs:
#     01_sources.conf: |-
#       <source>
#         @id fluentd-containers.log
#         @type tail
#         path /var/log/containers/*.log
#         pos_file /var/log/containers.log.pos
#         tag raw.kubernetes.*
#         read_from_head true
#         <parse>
#           @type multi_format
#           <pattern>
#             format json
#             time_key time
#             time_format %Y-%m-%dT%H:%M:%S.%NZ
#           </pattern>
#           <pattern>
#             format /^(?<time>.+) (?<stream>stdout|stderr) [^ ]* (?<log>.*)$/
#             time_format %Y-%m-%dT%H:%M:%S.%N%:z
#           </pattern>
#         </parse>
#       </source>

#     02_filters.conf: |-
#       # Detect exceptions in the log output and forward them as one log entry.
#       <match raw.kubernetes.**>
#         @id raw.kubernetes
#         @type detect_exceptions
#         remove_tag_prefix raw
#         message log
#         stream stream
#         multiline_flush_interval 5
#         max_bytes 500000
#         max_lines 1000
#       </match>

#       # Concatenate multi-line logs
#       <filter **>
#         @id filter_concat
#         @type concat
#         key message
#         multiline_end_regexp /\n$/
#         separator ""
#         timeout_label @NORMAL
#         flush_interval 5
#       </filter>

#       # Enriches records with Kubernetes metadata
#       <filter kubernetes.**>
#         @id filter_kubernetes_metadata
#         @type kubernetes_metadata
#       </filter>

#       # Fixes json fields in Elasticsearch
#       <filter kubernetes.**>
#         @id filter_parser
#         @type parser
#         key_name log
#         reserve_time true
#         reserve_data true
#         remove_key_name_field true
#         <parse>
#           @type multi_format
#           <pattern>
#             format json
#           </pattern>
#           <pattern>
#             format none
#           </pattern>
#         </parse>
#       </filter>

#     03_dispatch.conf: |-

#     04_outputs.conf: |-
#       # handle timeout log lines from concat plugin
#       <match **>
#         @type relabel
#         @label @NORMAL
#       </match>

#       <label @NORMAL>
#       <match **>
#         @id elasticsearch
#         @type elasticsearch
#         @log_level info
#         include_tag_key true
#         host "elasticsearch-master"
#         port 9200
#         path ""
#         scheme http
#         ssl_verify true
#         ssl_version TLSv1_2
#         type_name _doc
#         logstash_format true
#         logstash_prefix logstash
#         reconnect_on_error true
#         <buffer>
#           @type file
#           path /var/log/fluentd-buffers/kubernetes.system.buffer
#           flush_mode interval
#           retry_type exponential_backoff
#           flush_thread_count 2
#           flush_interval 5s
#           retry_forever
#           retry_max_interval 30
#           chunk_limit_size 2M
#           queue_limit_length 8
#           overflow_action block
#         </buffer>
#       </match>
#       </label>

#   EOF
#   ]

# }