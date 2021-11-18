resource "local_file" "mykubeconfig" {
    content     = <<KUBECONFIG
apiVersion: v1
clusters:
- cluster:
    server: ${data.aws_eks_cluster.cluster.endpoint}
    certificate-authority-data: ${data.aws_eks_cluster.cluster.certificate_authority.0.data}
  name: "arn:aws:eks:${var.region}:${data.aws_caller_identity.current.id}:cluster/${var.cluster_name}"
contexts:
- context:
    cluster: "arn:aws:eks:${var.region}:${data.aws_caller_identity.current.id}:cluster/${var.cluster_name}"
    user: "arn:aws:eks:${var.region}:${data.aws_caller_identity.current.id}:cluster/${var.cluster_name}"
  name: "arn:aws:eks:${var.region}:${data.aws_caller_identity.current.id}:cluster/${var.cluster_name}"
current-context: "arn:aws:eks:${var.region}:${data.aws_caller_identity.current.id}:cluster/${var.cluster_name}"
kind: Config
preferences: {}
users:
- name: "arn:aws:eks:${var.region}:${data.aws_caller_identity.current.id}:cluster/${var.cluster_name}"
  user:
    exec:
      apiVersion: client.authentication.k8s.io/v1alpha1
      args:
      - --region
      - ${var.region}
      - eks
      - get-token
      - --cluster-name
      - "${var.cluster_name}"
      command: aws
      
KUBECONFIG
    filename = "${var.kube_config_path}"
}