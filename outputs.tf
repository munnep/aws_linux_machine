output "linux_public-ip" {
  value = "ssh ubuntu@${aws_eip.terraform_linux-eip.public_ip}"
}
