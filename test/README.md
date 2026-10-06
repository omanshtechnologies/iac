# Terratest (plan-only)

Validates `modules/gh-runner-mig` and `modules/server` by running
`terraform plan` against the fixtures in `fixtures/` — each fixture is a
minimal root module with a placeholder `provider "google"` block, so plans
run fully offline: no real GCP project, credentials, or resources are
touched, and nothing is ever applied or destroyed.

Run locally:

```bash
cd test
go mod tidy   # first run only, resolves go.sum
go test ./... -v
```

Requires Go and the `terraform` CLI on PATH. CI runs the same thing in
`.github/workflows/lint.yml`.
