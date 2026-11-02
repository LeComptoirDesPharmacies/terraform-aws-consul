package test

import "testing"

func TestConsulClusterWithEncryptionAmazonLinuxAmi(t *testing.T) {
	t.Parallel()
	runConsulClusterTest(t, "amazon-linux-2023-ami", "examples/example-with-encryption", "../examples/example-with-encryption/packer/consul-with-certs.json", "ec2-user", "")
}
