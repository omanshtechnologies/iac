locals {
  labels = merge({ managed-by = "terraform", purpose = "github-runner" }, var.labels)
}
