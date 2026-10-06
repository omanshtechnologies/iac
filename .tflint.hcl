plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

# Google-specific rules (valid machine types/zones, deprecated arguments, etc).
# Check https://github.com/terraform-linters/tflint-ruleset-google/releases
# for the latest version and bump it here; `tflint --init` downloads it.
plugin "google" {
  enabled = true
  version = "0.30.0"
  source  = "github.com/terraform-linters/tflint-ruleset-google"
}

rule "terraform_unused_declarations" {
  enabled = true
}

rule "terraform_naming_convention" {
  enabled = true
}
