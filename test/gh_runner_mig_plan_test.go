package test

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

// Plan-only test: proves modules/gh-runner-mig's variables/resources wire up
// correctly and terraform can build a valid plan. Runs fully offline against
// the fixture's placeholder project — no real GCP credentials or resources
// are touched, nothing is applied or destroyed.
func TestGhRunnerMigPlan(t *testing.T) {
	t.Parallel()

	opts := &terraform.Options{
		TerraformDir: "./fixtures/gh-runner-mig",
		NoColor:      true,
	}

	terraform.RunTerraformCommand(t, opts, "init", "-backend=false", "-input=false")
	out := terraform.RunTerraformCommand(t, opts, "plan", "-input=false", "-no-color")

	assert.NotContains(t, out, "Error:")
	assert.Contains(t, out, "Plan: 4 to add, 0 to change, 0 to destroy.")
	assert.Contains(t, out, "google_compute_instance_template.runner")
	assert.Contains(t, out, "google_compute_health_check.vm_alive")
	assert.Contains(t, out, "google_compute_region_instance_group_manager.runners")
	assert.Contains(t, out, "google_compute_region_autoscaler.runners")
}
