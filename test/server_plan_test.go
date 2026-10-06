package test

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

// Plan-only test for modules/server — same offline, no-credentials-needed
// approach as the gh-runner-mig test.
func TestServerPlan(t *testing.T) {
	t.Parallel()

	opts := &terraform.Options{
		TerraformDir: "./fixtures/server",
		NoColor:      true,
	}

	terraform.RunTerraformCommand(t, opts, "init", "-backend=false", "-input=false")
	out := terraform.RunTerraformCommand(t, opts, "plan", "-input=false", "-no-color")

	assert.NotContains(t, out, "Error:")
	assert.Contains(t, out, "Plan: 1 to add, 0 to change, 0 to destroy.")
	assert.Contains(t, out, "google_compute_instance.vm")
}
