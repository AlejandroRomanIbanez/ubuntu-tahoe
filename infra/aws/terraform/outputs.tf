output "instance_id" {
  value = aws_instance.desktop_test.id
}

output "ami_id" {
  value = aws_instance.desktop_test.ami
}

output "public_ip" {
  value       = aws_instance.desktop_test.public_ip
  description = "Restrict access and destroy when testing is complete."
}

output "ssh_command" {
  value = "ssh -i ${local.key_path} ubuntu@${aws_instance.desktop_test.public_ip}"
}

output "vnc_tunnel_command" {
  value       = "ssh -i ${local.key_path} -N -L 5900:localhost:5900 ubuntu@${aws_instance.desktop_test.public_ip}  # then open a VNC viewer on localhost:5900"
  description = "VNC listens on the instance's loopback only; it is reachable only through this SSH tunnel."
}
