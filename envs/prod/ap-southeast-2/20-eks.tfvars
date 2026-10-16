environment        = "prod"
region             = "ap-southeast-2"
kubernetes_version = "1.37"

# GitHub-hosted runners (which bootstrap Argo CD) have no fixed IPs, so the public endpoint
# stays open to the internet and relies on IAM auth. Tighten this once a self-hosted runner
# runs inside the VPC.
public_access_cidrs = ["0.0.0.0/0"]

admin_principal_arns  = ["arn:aws:iam::827602717118:user/sabiut"]
viewer_principal_arns = []

node_instance_types = ["t3.large"] # lab profile: ["t3.medium"]
node_min_size       = 3
node_max_size       = 6
node_desired_size   = 3
