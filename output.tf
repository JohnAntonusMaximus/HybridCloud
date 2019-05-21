output "vpc_id" {
  description = "VPC ID"
  value       = "${module.exodus-prod.vpc_id}"
}

output "vpc_cidr_block" {
  description = "VPC CIDR Block"
  value       = ["${module.exodus-prod.vpc_cidr_block}"]
}

output "private_subnets" {
  description = "Private Subet IDs"
  value       = ["${module.exodus-prod.private_subnets}"]
}

output "public_subnets" {
  description = "Public Subet IDs"
  value       = ["${module.exodus-prod.public_subnets}"]
}


output "azs" {
  description = "Availability zones of VPC"
  value       = ["${module.exodus-prod.azs}"]
}

output "node-weather-public-ip" {
    value = ["${aws_instance.node-weather.*.public_ip}"]
}