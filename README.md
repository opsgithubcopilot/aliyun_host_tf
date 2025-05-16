# 阿里云 ECS Terraform 项目

这个项目使用Terraform创建阿里云ECS实例及其相关资源。项目设计为可以使用现有的VPC和交换机，或者在需要时创建新的资源。支持在多个可用区创建多台ECS实例，实现高可用性部署。

## 项目结构

- `main.tf` - 主要的Terraform配置文件，包含所有资源定义
- `variables.tf` - 变量定义文件
- `outputs.tf` - 输出定义文件
- `terraform.tfvars.example` - 变量值配置模板文件
- `.gitignore` - Git忽略文件配置

## 创建的资源

- 多个ECS实例（分布在不同可用区）
- 安全组（允许SSH、HTTP和HTTPS访问）
- 弹性公网IP（可选，每个实例一个）
- 密钥对（如果提供了公钥）
- VPC（如果未提供现有VPC ID）
- 多个交换机（如果未提供现有交换机ID，每个可用区一个）
- 云盘数据卷（每个实例一个，挂载到/data目录）

## 付费类型配置

项目支持两种付费类型：

1. **按量付费**（默认）：
   ```hcl
   instance_charge_type = "PostPaid"
   ```
   - 按实际使用时长计费
   - 可以随时释放实例
   - 适合测试环境或临时使用

2. **包年包月**：
   ```hcl
   instance_charge_type = "PrePaid"
   period = 1  # 购买时长（1-36个月）
   auto_renew = true  # 是否自动续费
   auto_renew_period = 1  # 自动续费时长（1-12个月）
   ```
   - 预先支付费用
   - 价格更优惠
   - 支持自动续费
   - 适合长期运行的生产环境

注意事项：
- 包年包月模式下，`period` 必须在 1-36 个月之间
- 启用自动续费时，`auto_renew_period` 必须在 1-12 个月之间
- 建议在切换到包年包月模式前，使用 `terraform plan` 查看费用预估
- 包年包月实例释放时可能会产生费用，请谨慎操作

## 安全组规则管理

项目支持灵活的安全组规则管理：

1. **使用现有安全组**：
   - 通过设置 `security_group_id` 使用现有安全组
   - 会自动备份现有规则到本地JSON文件
   - 只添加缺失的规则，不会修改或删除现有规则

2. **创建新安全组**：
   - 不设置 `security_group_id` 时自动创建新安全组
   - 包含以下默认规则：
     - SSH (22端口)
     - HTTP (80端口)
     - HTTPS (443端口)
     - 特殊IP访问规则（5511、8820、8823端口）

3. **规则备份**：
   - 使用现有安全组时会自动创建备份
   - 备份文件格式：`security_group_backup_[安全组ID]_[时间戳].json`
   - 备份包含完整的规则信息，便于恢复

## 密钥对管理

项目支持灵活的密钥对管理：

1. **使用现有密钥对**：
   - 通过 `existing_key_pairs` 变量指定现有密钥对名称列表
   - 自动检查密钥对是否存在于阿里云中
   - 避免重复创建已存在的密钥对

2. **创建新密钥对**：
   - 通过 `public_key_files` 变量提供公钥文件
   - 自动检查是否需要创建新密钥对
   - 为新建的密钥对添加随机后缀，避免命名冲突

3. **密钥对命名规则**：
   - 新建密钥对：`[原名称]-[随机后缀]`
   - 随机后缀：6位小写字母和数字组合
   - 确保密钥对名称在阿里云中唯一

## 标签系统

项目实现了全面的标签系统，所有资源都会自动添加以下标签：

- `Name` - 资源名称
- `Environment` - 环境名称（如dev、test、prod）
- `Owner` - 资源所有者
- `Department` - 部门名称
- `CostCenter` - 成本中心代码
- `Application` - 应用程序名称
- `Backup` - 是否需要备份
- `ManagedBy` - 管理工具（terraform）
- `CreatedAt` - 创建时间
- `Zone` - 实例所在的可用区（仅适用于实例）

此外，您可以通过`tags`变量添加自定义标签。

## 认证配置

您可以通过以下两种方式提供云服务访问凭证：

1. **环境变量**（推荐）：
   ```bash
   export ALICLOUD_ACCESS_KEY="your-access-key"
   export ALICLOUD_SECRET_KEY="your-secret-key"
   ```

2. **在terraform.tfvars中设置**：
   ```hcl
   cloud_access_key = "your-access-key"
   cloud_secret_key = "your-secret-key"
   ```

出于安全考虑，建议使用环境变量或其他安全的凭证管理方式，而不是将凭证直接写入配置文件。

## 登录方式配置

您可以选择使用SSH密钥或密码登录ECS实例：

1. **使用SSH密钥登录**（默认，推荐）：
   ```hcl
   login_mode = "key"
   public_key_files = ["path/to/your/key.pub"]
   ```

   SSH登录命令：
   ```bash
   # 使用默认密钥（~/.ssh/id_rsa）
   ssh root@<实例公网IP>

   # 指定密钥文件登录
   ssh -i /path/to/private_key root@<实例公网IP>

   # 指定密钥文件并设置严格权限（推荐）
   chmod 600 /path/to/private_key
   ssh -i /path/to/private_key root@<实例公网IP>

   # 指定端口登录（如果修改了默认SSH端口）
   ssh -i /path/to/private_key -p <端口号> root@<实例公网IP>

   # 启用详细输出（调试用）
   ssh -v -i /path/to/private_key root@<实例公网IP>
   ```

2. **使用密码登录**：
   ```hcl
   login_mode = "password"
   password = "YourStrongPassword123!"  # 密码必须包含大小写字母、数字和特殊字符
   ```

   密码登录命令：
   ```bash
   ssh root@<实例公网IP>
   # 然后输入配置的密码
   ```

出于安全考虑，建议使用SSH密钥登录而不是密码登录。

## 使用方法

1. 复制配置模板：
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

2. 编辑 `terraform.tfvars` 文件，设置您的配置参数：
   - 设置 `instance_count` 指定要创建的实例数量
   - 设置 `availability_zones` 指定要使用的可用区列表
   - 如果您想使用现有VPC，请设置 `vpc_id`
   - 如果您想使用现有交换机，请设置 `vswitch_id`
   - 如果您想使用现有安全组，请设置 `security_group_id`
   - 更新 `image_id` 为您所在区域的有效镜像ID
   - 如果需要SSH访问，请提供 `public_key_files`
   - 设置标签相关变量，如 `environment`、`owner` 等
   - 可以设置 `data_volume_size` 来指定数据卷大小（默认100GB）
   - 设置付费类型相关参数：
     ```hcl
     # 按量付费（默认）
     instance_charge_type = "PostPaid"
     
     # 或包年包月
     # instance_charge_type = "PrePaid"
     # period = 1
     # auto_renew = true
     # auto_renew_period = 1
     ```

3. 初始化Terraform：
   ```bash
   terraform init
   ```

4. 查看将要创建的资源：
   ```bash
   terraform plan
   ```

5. 应用配置创建资源：
   ```bash
   terraform apply
   ```

6. 完成后，Terraform将输出创建的资源信息，包括ECS实例的IP地址和数据卷信息。

## 多可用区部署

项目支持在多个可用区部署ECS实例，以提高系统的可用性：

- 通过 `availability_zones` 变量指定要使用的可用区列表
- 实例会按照轮询方式分布在指定的可用区中
- 每个可用区会创建一个交换机（如果未提供现有交换机）
- 每个实例的标签中会包含其所在的可用区信息

## 数据卷

项目会为每个实例创建一个额外的云盘并将其挂载到ECS实例的`/data`目录下：

- 数据卷大小可以通过`data_volume_size`变量设置（默认为100GB）
- 数据卷会在实例启动时自动格式化为ext4文件系统并挂载
- 挂载点会添加到`/etc/fstab`以确保实例重启后自动挂载

## 自定义

- 修改 `variables.tf` 中的默认值以适应您的需求
- 编辑 `main.tf` 添加更多资源或修改现有资源配置
- 在 `terraform.tfvars` 中添加自定义标签

## 清理资源

要删除所有创建的资源，请运行：

```bash
terraform destroy
```

## 注意事项

- 确保您的阿里云账号有足够的权限创建这些资源
- 使用前请确认您的账号余额充足，以避免因余额不足导致资源创建失败
- 请根据您的实际需求选择合适的实例规格和存储类型
- 建议在生产环境中使用更安全的访问控制策略，而不是允许所有IP访问
- 在多可用区部署时，请确保所选区域中的所有可用区都支持您选择的实例规格
- 使用现有安全组时，请确保您有足够的权限修改安全组规则
- 密钥对管理时，请确保公钥文件的格式正确，且具有适当的读取权限
- 建议定期备份安全组规则，特别是在进行大规模规则修改之前
- 选择付费类型时，请根据实际使用场景和预算进行选择：
  - 测试环境建议使用按量付费，便于随时释放资源
  - 生产环境建议使用包年包月，可以获得更优惠的价格
  - 使用包年包月时，建议启用自动续费，避免因忘记续费导致服务中断
