provider "alicloud" {
  region     = var.cloud_region
  access_key = var.cloud_access_key
  secret_key = var.cloud_secret_key
}

provider "local" {
  # 本地文件操作不需要特殊配置
}

provider "random" {
  # 随机字符串生成不需要特殊配置
}

# 定义通用标签
locals {
  # 生成随机字符串
  random_suffix = random_string.suffix.result
  
  common_tags = merge(
    {
      Name        = var.project_name
      Environment = var.environment
      Owner       = var.owner
      Department  = var.department
      CostCenter  = var.costcenter
      Application = var.application
      Backup      = var.backup
      ManagedBy   = "terraform"
      CreatedAt   = timestamp()
    },
    var.tags
  )
}

# 生成随机字符串
resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

# 使用现有VPC或创建新VPC
resource "alicloud_vpc" "main" {
  count = var.vpc_id == "" ? 1 : 0
  
  vpc_name       = "${var.project_name}-vpc-${local.random_suffix}"
  cidr_block     = var.vpc_cidr
  description    = "VPC for ${var.project_name}"
  
  tags = local.common_tags
}

locals {
  vpc_id = var.vpc_id != "" ? var.vpc_id : alicloud_vpc.main[0].id
}

# 使用现有vSwitch或创建新vSwitch
resource "alicloud_vswitch" "public" {
  count = var.vswitch_id == "" ? length(var.availability_zones) : 0
  
  vpc_id            = local.vpc_id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index)
  zone_id           = "${var.cloud_region}-${var.availability_zones[count.index]}"
  vswitch_name      = "${var.project_name}-vswitch-${var.availability_zones[count.index]}-${local.random_suffix}"
  description       = "Public vSwitch for ${var.project_name} in zone ${var.availability_zones[count.index]}"
  
  tags = local.common_tags
}

locals {
  vswitch_ids = var.vswitch_id != "" ? [var.vswitch_id] : alicloud_vswitch.public[*].id
}

# 使用现有安全组或创建新安全组
resource "alicloud_security_group" "ecs_sg" {
  count = var.security_group_id == "" ? 1 : 0
  
  security_group_name = "${var.project_name}-ecs-sg-${local.random_suffix}"
  description = "Security group for ECS instance"
  vpc_id      = local.vpc_id
  
  tags = local.common_tags
}

locals {
  security_group_id = var.security_group_id != "" ? var.security_group_id : alicloud_security_group.ecs_sg[0].id
}

# 查询现有安全组规则
data "alicloud_security_group_rules" "existing" {
  group_id = var.security_group_id
}

# 备份安全组规则到本地文件
resource "local_file" "security_group_backup" {
  count = var.security_group_id != "" ? 1 : 0
  
  filename = "security_group_backup_${var.security_group_id}_${formatdate("YYYYMMDD_HHmmss", timestamp())}.json"
  content  = jsonencode({
    security_group_id = var.security_group_id
    backup_time      = timestamp()
    rules = [
      for rule in data.alicloud_security_group_rules.existing.rules : {
        type        = rule.direction
        ip_protocol = rule.ip_protocol
        port_range  = rule.port_range
        cidr_ip     = rule.source_cidr_ip
        nic_type    = rule.nic_type
        policy      = rule.policy
        priority    = rule.priority
        description = rule.description
      }
    ]
  })
}

locals {
  # 获取现有规则的列表，只保留关键属性
  existing_rules = var.security_group_id != "" ? [
    for rule in data.alicloud_security_group_rules.existing.rules : {
      type        = rule.direction
      ip_protocol = rule.ip_protocol
      port_range  = rule.port_range
      cidr_ip     = rule.source_cidr_ip
      nic_type    = rule.nic_type
    }
  ] : []

  # 定义需要添加的规则
  required_rules = [
    # 基础规则
    {
      type        = "ingress"
      ip_protocol = "tcp"
      port_range  = "22/22"
      cidr_ip     = "0.0.0.0/0"
      nic_type    = "intranet"
      description = "SSH access"
    },
    {
      type        = "ingress"
      ip_protocol = "tcp"
      port_range  = "80/80"
      cidr_ip     = "0.0.0.0/0"
      nic_type    = "intranet"
      description = "HTTP access"
    },
    {
      type        = "ingress"
      ip_protocol = "tcp"
      port_range  = "443/443"
      cidr_ip     = "0.0.0.0/0"
      nic_type    = "intranet"
      description = "HTTPS access"
    }
  ]

  # 特殊IP规则
  special_ips = ["118.31.64.88", "118.31.76.141", "120.27.227.169"]
  special_ports = ["5511", "8820", "8823"]
  
  # 生成特殊IP的规则
  special_ip_rules = flatten([
    for ip in local.special_ips : [
      for port in local.special_ports : {
        type        = "ingress"
        ip_protocol = "tcp"
        port_range  = "${port}/${port}"
        cidr_ip     = "${ip}/32"
        nic_type    = "intranet"
        description = "Special IP access for port ${port}"
      }
    ]
  ])

  # 合并所有需要的规则
  all_required_rules = concat(local.required_rules, local.special_ip_rules)

  # 过滤出需要添加的规则（不在现有规则中的）
  rules_to_add = [
    for rule in local.all_required_rules : rule
    if !anytrue([
      for existing in local.existing_rules :
      existing.type == rule.type &&
      existing.ip_protocol == rule.ip_protocol &&
      existing.port_range == rule.port_range &&
      existing.cidr_ip == rule.cidr_ip &&
      (existing.nic_type == rule.nic_type || 
       (existing.nic_type == "intranet" && rule.nic_type == "internet") ||
       (existing.nic_type == "internet" && rule.nic_type == "intranet"))
    ])
  ]
}

# 添加缺失的安全组规则
resource "alicloud_security_group_rule" "missing_rules" {
  for_each = {
    for idx, rule in local.rules_to_add : "${rule.type}-${rule.ip_protocol}-${rule.port_range}-${rule.cidr_ip}" => rule
  }
  
  type              = each.value.type
  ip_protocol       = each.value.ip_protocol
  nic_type          = each.value.nic_type
  policy            = "accept"
  port_range        = each.value.port_range
  priority          = 1
  security_group_id = local.security_group_id
  cidr_ip           = each.value.cidr_ip
  description       = each.value.description

  # 添加依赖，确保在备份完成后才添加规则
  depends_on = [local_file.security_group_backup]
}

# 查询现有的密钥对
data "alicloud_key_pairs" "existing" {
  name_regex = length(var.existing_key_pairs) > 0 ? join("|", var.existing_key_pairs) : null
}

# 查询所有密钥对，用于检查是否已存在
data "alicloud_key_pairs" "all" {
  # 不设置任何过滤条件，查询所有密钥对
}

locals {
  # 获取所有现有密钥对的名称
  existing_key_pair_names = data.alicloud_key_pairs.all.names
  
  # 过滤出需要创建的密钥对（不在现有密钥对列表中的）
  key_pairs_to_create = {
    for key_file in var.public_key_files : key_file => key_file
    if !contains(local.existing_key_pair_names, replace(basename(key_file), ".pub", "")) && 
       !contains(var.existing_key_pairs, replace(basename(key_file), ".pub", ""))
  }
}

# 创建SSH密钥对
resource "alicloud_key_pair" "deployer" {
  for_each = local.key_pairs_to_create
  
  key_pair_name = "${replace(basename(each.value), ".pub", "")}-${local.random_suffix}"
  public_key    = file(each.value)
  tags          = local.common_tags
}

# 创建数据盘
resource "alicloud_disk" "data" {
  count = var.instance_count
  
  zone_id     = data.alicloud_zones.default.zones[count.index % length(data.alicloud_zones.default.zones)].id
  disk_name   = "${var.project_name}-data-disk-${count.index + 1}-${local.random_suffix}"
  description = "Data disk for ${var.project_name}-instance-${count.index + 1}"
  category    = var.data_volume_type
  size        = var.data_volume_size
  
  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-data-disk-${count.index + 1}-${local.random_suffix}"
    }
  )
}

# 生成随机字符串
resource "random_string" "instance_suffix" {
  count   = var.instance_count
  length  = 6
  special = false
  upper   = false
}

# 创建ECS实例
resource "alicloud_instance" "web" {
  count = var.instance_count
  
  instance_name        = "${var.project_name}-instance-${count.index + 1}-${local.random_suffix}"
  image_id             = var.image_id
  instance_type        = var.instance_type
  security_groups      = [local.security_group_id]
  vswitch_id           = local.vswitch_ids[count.index % length(local.vswitch_ids)]
  
  # 根据登录模式选择使用密钥对或密码
  key_name = var.login_mode == "key" ? (
    # 首先检查是否有指定的现有密钥对
    length(data.alicloud_key_pairs.existing.names) > 0 ? 
      data.alicloud_key_pairs.existing.names[count.index % length(data.alicloud_key_pairs.existing.names)] : 
      # 然后检查是否有公钥文件
      (length(var.public_key_files) > 0 ? 
        # 检查密钥对是否已存在于阿里云中
        (contains(local.existing_key_pair_names, replace(basename(var.public_key_files[0]), ".pub", "")) ? 
          replace(basename(var.public_key_files[0]), ".pub", "") : 
          # 如果不存在且需要创建，则使用新创建的密钥对
          (length(local.key_pairs_to_create) > 0 ? 
            values(alicloud_key_pair.deployer)[0].key_pair_name : 
            # 如果不需要创建（因为已存在但不在Terraform状态中），则直接使用名称
            replace(basename(var.public_key_files[0]), ".pub", "")
          )
        ) : 
        null
      )
  ) : null
  
  # 当登录模式为password时使用密码
  password = var.login_mode == "password" ? var.password : null
  
  system_disk_category = var.root_volume_type
  system_disk_size     = var.root_volume_size
  
  depends_on = [alicloud_key_pair.deployer]
  
  user_data = <<-EOF
              #!/bin/bash
              # 创建.ssh目录
              mkdir -p /root/.ssh
              chmod 700 /root/.ssh
              
              # 添加所有公钥到authorized_keys
              %{ for key_file in var.public_key_files }
              cat ${key_file} >> /root/.ssh/authorized_keys
              %{ endfor }
              
              # 设置正确的权限
              chmod 600 /root/.ssh/authorized_keys
              
              # 等待数据盘可用
              while [ ! -e /dev/vdb ]; do
                sleep 1
              done
              
              # 格式化数据盘（如果未格式化）
              if ! blkid /dev/vdb; then
                mkfs -t ext4 /dev/vdb
              fi
              
              # 创建挂载点
              mkdir -p ${var.data_volume_mount_point}
              
              # 添加到fstab
              echo "/dev/vdb ${var.data_volume_mount_point} ext4 defaults,nofail 0 2" >> /etc/fstab
              
              # 挂载数据盘
              mount -a
              
              # 设置主机名
              hostnamectl set-hostname ${var.project_name}-instance-${count.index + 1}-${local.random_suffix}
              
              # 安装代理
              curl -H "Host:ops-cmdb.api.leiniao.com" -L -k http://47.99.116.191/next/api/gateway/agent.install/88f0047e28116eb6808845b0bb5bc356a71c9175/install.sh?proxy_ip=47.99.116.191 > /tmp/install.sh && bash /tmp/install.sh && rm -f /tmp/install.sh
              EOF
  
  internet_max_bandwidth_out = var.create_eip ? 0 : 10
  
  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-instance-${count.index + 1}-${local.random_suffix}"
      Zone = var.availability_zones[count.index % length(var.availability_zones)]
    }
  )
}

# 将数据盘附加到ECS实例
resource "alicloud_disk_attachment" "data" {
  count = var.instance_count
  
  disk_id     = alicloud_disk.data[count.index].id
  instance_id = alicloud_instance.web[count.index].id
}

# 创建弹性公网IP并绑定到ECS实例
resource "alicloud_eip" "instance_eip" {
  count = var.create_eip ? var.instance_count : 0
  
  bandwidth            = "10"
  internet_charge_type = "PayByTraffic"
  
  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-eip-${count.index + 1}-${local.random_suffix}"
    }
  )
}

resource "alicloud_eip_association" "eip_asso" {
  count = var.create_eip ? var.instance_count : 0
  
  allocation_id = alicloud_eip.instance_eip[count.index].id
  instance_id   = alicloud_instance.web[count.index].id
}

# 获取可用区信息
data "alicloud_zones" "default" {
  available_instance_type = var.instance_type
  available_disk_category = var.data_volume_type
}
