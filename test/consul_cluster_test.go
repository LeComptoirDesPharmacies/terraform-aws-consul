package test

import (
	"testing"
)

// Test the example in the root folder
func TestConsulClusterWithAmazonLinuxAmi(t *testing.T) {
	t.Parallel()
	runConsulClusterTest(t, "amazon-linux-2023-ami", ".", "../examples/consul-ami/consul.json", "ec2-user", "")
}
