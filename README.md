# GitHub Actions runners on GCP (Terraform)

Regional Managed Instance Group of Ubuntu 24.04 VMs (e2-medium: 2 vCPU / 4 GB, 20 GB disk)
that register themselves as GitHub Actions runners. A scheduled autoscaler runs them
**09:00–19:00 IST daily** and scales to **0 VMs** outside that window, so you pay for ~10 h/day.

## Deploy

```bash
cp terraform.tfvars.example terraform.tfvars   # set project_id, github_owner
terraform init
terraform apply -target=google_secret_manager_secret.github_pat   # creates APIs + empty secret
```

Store a GitHub token (never goes into Terraform state):

* Org runners: classic PAT with `admin:org`, or fine-grained PAT with Organization → *Self-hosted runners: Read & write*.
* Repo runners (`github_repo` set): fine-grained PAT with Repository → *Administration: Read & write*.

```bash
printf '%s' "$GITHUB_PAT" | gcloud secrets versions add gh-runner-github-pat --project=<PROJECT> --data-file=-
terraform apply
```

Use in workflows with `runs-on: [self-hosted, gcp]`.

## CI deployment (GitHub Actions)

`.github/workflows/deploy-runners.yml` deploys this module on manual
dispatch, with inputs for VM type (`vm_type`), the runner name prefix
(`runner_name`), and the max fleet size (`runner_count`). It runs on
GitHub-hosted runners (not the fleet it manages, to avoid a bootstrap
chicken-and-egg problem) and authenticates to GCP via Workload Identity
Federation — no long-lived key is stored anywhere.

`.github/workflows/destroy-runners.yml` tears it back down: `terraform
destroy`, then deregisters any GitHub runner whose name starts with
`<runner_name>.` (the `${runner_name}.${zone}` scheme the module
registers under) — independent of whether the VM's own shutdown-script
deregistration got a chance to run. Requires typing `destroy` into the
`confirm` input to guard against an accidental dispatch. Uses the same
one-time setup and repo variables as the deploy workflow.

One-time setup, before the workflow can run for the first time:

1. **State bucket** (Terraform state can't live on a GitHub-hosted runner's
   ephemeral disk):

   ```bash
   gsutil mb -l asia-south1 gs://<project>-tfstate
   gsutil versioning set on gs://<project>-tfstate
   ```

2. **Deploy service account**, scoped to what this module manages:

   ```bash
   gcloud iam service-accounts create gh-actions-terraform \
     --display-name="GitHub Actions Terraform deployer"

   for role in roles/compute.admin roles/iam.serviceAccountAdmin \
     roles/iam.serviceAccountUser roles/resourcemanager.projectIamAdmin \
     roles/secretmanager.admin roles/serviceusage.serviceUsageAdmin; do
     gcloud projects add-iam-policy-binding <project> \
       --member="serviceAccount:gh-actions-terraform@<project>.iam.gserviceaccount.com" \
       --role="$role"
   done

   gsutil iam ch \
     serviceAccount:gh-actions-terraform@<project>.iam.gserviceaccount.com:roles/storage.objectAdmin \
     gs://<project>-tfstate
   ```

3. **Workload Identity Federation**, restricted to this repo:

   ```bash
   gcloud iam workload-identity-pools create "github" --location="global"

   gcloud iam workload-identity-pools providers create-oidc "github" \
     --location="global" --workload-identity-pool="github" \
     --issuer-uri="https://token.actions.githubusercontent.com" \
     --attribute-mapping="google.subject=assertion.sub,attribute.repository=assertion.repository" \
     --attribute-condition="assertion.repository=='<owner>/<repo>'"

   gcloud iam service-accounts add-iam-policy-binding \
     gh-actions-terraform@<project>.iam.gserviceaccount.com \
     --role="roles/iam.workloadIdentityUser" \
     --member="principalSet://iam.googleapis.com/projects/<project-number>/locations/global/workloadIdentityPools/github/attribute.repository/<owner>/<repo>"
   ```

4. **Repo variables** (Settings → Secrets and variables → Actions →
   Variables — none of these are secret once WIF is used):

   | Variable | Value |
   |---|---|
   | `GCP_PROJECT_ID` | `<project>` |
   | `GH_RUNNER_OWNER` | GitHub org/user the runners register under |
   | `GH_RUNNER_REPO` | repo name for repo-level runners (leave unset for org-level) |
   | `TF_STATE_BUCKET` | `<project>-tfstate` |
   | `GCP_WIF_PROVIDER` | `projects/<project-number>/locations/global/workloadIdentityPools/github/providers/github` |
   | `GCP_DEPLOY_SA` | `gh-actions-terraform@<project>.iam.gserviceaccount.com` |

5. **Org secret** (org Settings → Secrets and variables → Actions →
   Secrets, visible to this repo): `GH_PAT` — the GitHub PAT described above
   (`admin:org`, or fine-grained *Self-hosted runners: Read & write* /
   *Administration: Read & write*). This is an org-level secret, not a
   repo-level one, so it's managed once centrally rather than per-repo.
   After every `terraform apply`, the
   workflow writes its value into Secret Manager as a new secret version via
   `gcloud secrets versions add` (using the `roles/secretmanager.admin` grant
   from step 2) — it never touches Terraform state. Rotate by updating this
   one secret; no re-run of the manual `gcloud secrets versions add` command
   from *Deploy* above is needed for CI-driven deploys.

## How it works

| Concern | Design |
|---|---|
| Schedule | `google_compute_region_autoscaler` scaling schedule (`Asia/Kolkata`, cron `0 9 * * *`, 10 h). Min 0 outside it. Change with `schedule_cron` (e.g. `0 9 * * 1-5` for weekdays). |
| Scalable | Inside the window: `min_runners` (1) up to `max_runners` (3) on CPU > 60 %. `max_runners` is also your cost cap. |
| Reliable | Regional MIG across 3 zones, auto-healing health check, runners deregister from GitHub on shutdown, fresh patched image every morning. |
| Network | Project's existing **default** network/subnet (no dedicated VPC). Runners get an ephemeral **public IP** (`assign_public_ip = true`); set false to go private + Cloud NAT. Relies on GCP's built-in `default-allow-ssh`/`default-allow-internal`/`default-allow-icmp` firewall rules — no custom firewall rules are created. |
| Access | OS Login only (no static keys, project SSH keys blocked, serial port off). Grant users via `ssh_members`. IAP SSH is also enabled. |
| Secrets | GitHub token in Secret Manager; the VM service account can read only that secret. Token is held in memory only. |
| VM hardening | Shielded VM (secure boot, vTPM, integrity monitoring), runner runs as non-root `runner` user, dedicated least-privilege service account. |
| Cost | No compute outside the window, no Cloud NAT when public IPs are used, `pd-balanced` 20 GB, optional `use_spot = true` (~60–90 % cheaper). |

## Linting & testing

* **tflint** — config in [.tflint.hcl](.tflint.hcl) (core + Google ruleset).
  Run `tflint --init && tflint --recursive` from this directory.
* **Terratest** — plan-only tests in [test/](test/) for `modules/gh-runner-mig`
  and `modules/server`, run against placeholder fixtures so no real GCP
  project/credentials are needed and nothing is applied or destroyed. Run
  `cd test && go test ./... -v`.
* **CI** — `.github/workflows/lint.yml` runs `terraform fmt -check`,
  `terraform validate` (root + each module), tflint, and the Terratest suite
  on every PR touching `iac/**`. None of these jobs need GCP credentials.

## Things to know

* **SSH relies on the project's `default-allow-ssh` rule** (open to `0.0.0.0/0`, gated by OS Login). If that rule has been deleted or narrowed on your project, SSH/IAP/health-check probes will stop working — re-add dedicated firewall rules in [network.tf](network.tf) in that case.
* **Jobs running at 19:00** are stopped when VMs are removed. Scale-in is limited to 1 VM / 5 min, so shutdown after 19:00 can take a few extra minutes.
* **Spot** can interrupt jobs mid-run; fine for re-runnable CI, off by default.
* **Public repos:** never attach self-hosted runners to public repositories (untrusted PR code would run on your VMs).
* Each morning the VM installs the runner (~2–3 min). For faster starts, bake a custom image with Packer.
* Public IPv4 addresses are billed per hour while in use (small, only during the window).
* Debug a VM: `gcloud compute ssh <vm> --zone <zone>` and read `/var/log/runner-startup.log`.
