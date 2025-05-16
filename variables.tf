variable "cloud_region" {
  description = "云服务区域"
  type        = string
  default     = "cn-hangzhou"
}

variable "availability_zones" {
  description = "可用区后缀列表，例如['a', 'b', 'c']"
  type        = list(string)
  default     = ["a", "b"]
}

variable "project_name" {
  description = "项目名称，用于资源命名"
  type        = string
  default     = "terraform-ecs"
}

variable "environment" {
  description = "环境名称，如dev、test、prod等"
  type        = string
  default     = "dev"
}

variable "owner" {
  description = "资源所有者，通常是团队或个人名称"
  type        = string
  default     = "terraform"
}

variable "department" {
  description = "部门名称"
  type        = string
  default     = "it"
}

variable "costcenter" {
  description = "成本中心代码"
  type        = string
  default     = "cc-123"
}

variable "tags" {
  description = "应用到所有资源的附加标签"
  type        = map(string)
  default     = {}
}

variable "vpc_id" {
  description = "现有VPC的ID，如果为空则创建新的VPC"
  type        = string
  default     = ""
}

variable "vpc_cidr" {
  description = "VPC的CIDR块，仅在创建新VPC时使用"
  type        = string
  default     = "10.0.0.0/16"
}

variable "vswitch_id" {
  description = "现有交换机的ID，如果为空则创建新的交换机"
  type        = string
  default     = ""
}

variable "security_group_id" {
  description = "现有安全组的ID，如果为空则创建新的安全组"
  type        = string
  default     = ""
}

variable "image_id" {
  description = "实例的镜像ID"
  type        = string
  default     = "centos_7_9_x64_20G_alibase_20230816.vhd" # CentOS 7.9 64位
}

variable "instance_type" {
  description = "实例类型"
  type        = string
  default     = "ecs.g6.large" # 2核8GB
}

variable "root_volume_size" {
  description = "根卷大小(GB)"
  type        = number
  default     = 40
}

variable "root_volume_type" {
  description = "根卷类型，可选值：cloud_efficiency, cloud_ssd, cloud_essd"
  type        = string
  default     = "cloud_efficiency"
}

variable "data_volume_size" {
  description = "数据卷大小(GB)"
  type        = number
  default     = 100
}

variable "data_volume_type" {
  description = "数据卷类型，可选值：cloud_efficiency, cloud_ssd, cloud_essd"
  type        = string
  default     = "cloud_efficiency"
}

variable "data_volume_mount_point" {
  description = "数据卷挂载点"
  type        = string
  default     = "/data"
}

variable "public_key_files" {
  description = "SSH公钥文件路径列表"
  type        = list(string)
  default     = []
}

variable "existing_key_pairs" {
  description = "现有密钥对名称列表"
  type        = list(string)
  default     = []
}

variable "create_eip" {
  description = "是否为ECS实例创建弹性公网IP"
  type        = bool
  default     = true
}

variable "instance_count" {
  description = "要创建的ECS实例数量"
  type        = number
  default     = 1
}

variable "login_mode" {
  description = "登录模式，可选值：'key'（使用SSH密钥）或'password'（使用密码）"
  type        = string
  default     = "key"
  validation {
    condition     = contains(["key", "password"], var.login_mode)
    error_message = "登录模式必须是'key'或'password'之一。"
  }
}

variable "password" {
  description = "当login_mode为'password'时，用于ECS实例的登录密码"
  type        = string
  default     = ""
  sensitive   = true
}

variable "cloud_access_key" {
  description = "云服务访问密钥ID (Access Key ID)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "cloud_secret_key" {
  description = "云服务访问密钥密码 (Secret Key)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "application" {
  description = "应用名称"
  type        = string
  default     = "web-app"
}

variable "backup" {
  description = "是否需要备份，true/false"
  type        = string
  default     = "true"
}
