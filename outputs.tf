output "instance_ids" {
  description = "实例的ID列表"
  value       = alicloud_instance.web[*].id
}

output "instance_public_ips" {
  description = "实例的公网IP地址列表"
  value       = var.create_eip ? alicloud_eip.instance_eip[*].ip_address : alicloud_instance.web[*].public_ip
}

output "instance_private_ips" {
  description = "实例的私网IP地址列表"
  value       = alicloud_instance.web[*].private_ip
}

output "data_volume_ids" {
  description = "数据卷的ID列表"
  value       = alicloud_disk.data[*].id
}

output "data_volume_sizes" {
  description = "数据卷的大小(GB)列表"
  value       = alicloud_disk.data[*].size
}

output "vpc_id" {
  description = "VPC的ID"
  value       = local.vpc_id
}

output "subnet_ids" {
  description = "网络子网的ID列表"
  value       = local.vswitch_ids
}

output "security_group_id" {
  description = "安全组的ID"
  value       = local.security_group_id
}

output "eip_addresses" {
  description = "弹性公网IP地址列表（如果创建）"
  value       = var.create_eip ? alicloud_eip.instance_eip[*].ip_address : null
}

output "availability_zones" {
  description = "实例部署的可用区列表"
  value       = [for i, instance in alicloud_instance.web : "${var.cloud_region}-${var.availability_zones[i % length(var.availability_zones)]}"]
}
