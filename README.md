# Azure Verified Modules – Virtual Machine Lab

A hands-on lab showing how to deploy Azure Virtual Machines using the
[Azure Verified Module (AVM) for Compute: Virtual Machine](https://registry.terraform.io/modules/Azure/avm-res-compute-virtualmachine/azurerm).

Each VM lives in its own folder under `infrastructure/virtual-machines/`, making
it easy to manage, diff, and deploy VMs independently.

---

## Table of Contents

1. [What is an Azure Verified Module?](#what-is-an-azure-verified-module)
2. [Repository Layout](#repository-layout)
3. [Prerequisites](#prerequisites)
4. [Quick Start – Deploy Your First VM](#quick-start--deploy-your-first-vm)
5. [Adding a New VM](#adding-a-new-vm)
6. [Variable Reference](#variable-reference)
7. [Common Image References](#common-image-references)
8. [Remote State Setup](#remote-state-setup)
9. [CI/CD with GitHub Actions](#cicd-with-github-actions)
10. [Destroying Resources](#destroying-resources)

---

## What is an Azure Verified Module?

Azure Verified Modules (AVM) are opinionated, Microsoft-maintained Terraform
modules that follow security and compliance best practices. Using them means:

- Consistent resource naming and tagging
- Security defaults (boot diagnostics, managed identities, etc.)
- Regular updates aligned with Azure provider changes
- One well-tested module instead of hand-rolled resource blocks

The VM module used here:
```
Azure/avm-res-compute-virtualmachine/azurerm
```

Full documentation: <https://registry.terraform.io/modules/Azure/avm-res-compute-virtualmachine/azurerm>

---

## Repository Layout

```
terraform-avm-azurevm/
│
├── .github/
│   └── workflows/
│       ├── terraform-plan.yml      # Runs on pull request – validates & plans
│       ├── terraform-apply.yml     # Runs on merge to main – applies changes
│       └── terraform-destroy.yml   # Manual workflow – destroys a VM
│
├── infrastructure/
│   └── virtual-machines/
│       └── example-vm/             # Reference VM configuration
│           ├── main.tf
│           ├── variables.tf
│           ├── outputs.tf
│           └── terraform.tfvars.template
│
├── templates/
│   └── vm/                         # Blank template – copy this for each new VM
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       └── terraform.tfvars.template
│
├── .gitignore
├── LICENSE
└── README.md
```

**One folder = one VM.**
Each VM folder is a self-contained Terraform root module with its own state file
in Azure Blob Storage. Add a new VM by copying `templates/vm/` – nothing else
needs to change.

---

## Prerequisites

| Tool | Minimum version | Install |
|------|----------------|---------|
| Terraform | 1.9+ | <https://developer.hashicorp.com/terraform/install> |
| Azure CLI | 2.60+ | <https://learn.microsoft.com/cli/azure/install-azure-cli> |
| An Azure subscription | – | <https://azure.microsoft.com/free/> |

You also need an Azure Storage Account to store Terraform remote state.
See [Remote State Setup](#remote-state-setup) if you don't have one yet.

---

## Quick Start – Deploy Your First VM

### 1. Clone the repository

```bash
git clone https://github.com/<your-org>/terraform-avm-azurevm.git
cd terraform-avm-azurevm
```

### 2. Log in to Azure

```bash
az login
az account set --subscription "<your-subscription-id>"
```

### 3. Create your tfvars file

```bash
cd infrastructure/virtual-machines/example-vm
cp terraform.tfvars.template terraform.tfvars
```

Open `terraform.tfvars` in your editor and fill in at minimum:

```hcl
subscription_id     = "00000000-0000-0000-0000-000000000000"
resource_group_name = "rg-example-vm"
vm_name             = "example-vm"
```

> `terraform.tfvars` is git-ignored – it will never be committed.

### 4. Update the backend block

Open `main.tf` and update the `backend "azurerm"` block with your storage
account details:

```hcl
backend "azurerm" {
  resource_group_name  = "rg-tfstate"
  storage_account_name = "satfstate<unique-suffix>"
  container_name       = "tfstate"
  key                  = "example-vm.terraform.tfstate"
}
```

Alternatively, pass these values at `terraform init` time (see
[Remote State Setup](#remote-state-setup)).

### 5. Initialise, plan, and apply

```bash
terraform init
terraform plan
terraform apply
```

Type `yes` when prompted. Terraform will create:

- A resource group
- A virtual network and subnet (if `create_vnet = true`)
- A virtual machine via the AVM module

### 6. Get the VM's private IP

```bash
terraform output private_ip_address
```

---

## Adding a New VM

```bash
# 1. Copy the template
cp -r templates/vm infrastructure/virtual-machines/<new-vm-name>

# 2. Create your tfvars
cd infrastructure/virtual-machines/<new-vm-name>
cp terraform.tfvars.template terraform.tfvars

# 3. Edit terraform.tfvars with the new VM's values
#    At minimum: subscription_id, resource_group_name, vm_name

# 4. Update the backend key in main.tf
#    key = "<new-vm-name>.terraform.tfstate"

# 5. Deploy
terraform init
terraform plan
terraform apply
```

Each VM has its own state file (`<vm-name>.terraform.tfstate`) in the shared
storage container, so VMs are completely independent of each other.

---

## Variable Reference

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `subscription_id` | string | – | **Required.** Azure subscription ID. |
| `location` | string | `"uksouth"` | Azure region. |
| `resource_group_name` | string | – | **Required.** Name of the resource group to create. |
| `tags` | map(string) | `{}` | Tags applied to all resources. |
| `create_vnet` | bool | `true` | Create a new VNet/Subnet. Set `false` + supply `existing_subnet_id` for brownfield. |
| `vnet_name` | string | `"vnet-main"` | VNet name (only when `create_vnet = true`). |
| `vnet_address_space` | string | `"10.0.0.0/16"` | VNet CIDR (only when `create_vnet = true`). |
| `subnet_name` | string | `"snet-vms"` | Subnet name (only when `create_vnet = true`). |
| `subnet_address_prefix` | string | `"10.0.1.0/24"` | Subnet CIDR (only when `create_vnet = true`). |
| `existing_subnet_id` | string | `null` | Full resource ID of an existing subnet (only when `create_vnet = false`). |
| `vm_name` | string | – | **Required.** VM name. |
| `os_type` | string | `"Linux"` | `"Linux"` or `"Windows"`. |
| `vm_size` | string | `"Standard_B2s"` | Azure VM SKU. |
| `image_publisher` | string | `"Canonical"` | Marketplace image publisher. |
| `image_offer` | string | `"0001-com-ubuntu-server-jammy"` | Marketplace image offer. |
| `image_sku` | string | `"22_04-lts-gen2"` | Marketplace image SKU. |
| `os_disk_type` | string | `"StandardSSD_LRS"` | OS disk storage tier. |
| `admin_username` | string | `"azureadmin"` | VM administrator username. |
| `generate_admin_credentials` | bool | `true` | Let AVM auto-generate and store credentials. |
| `admin_password` | string | `null` | Admin password (only when `generate_admin_credentials = false`). |
| `disable_password_auth` | bool | `true` | Linux: disable password auth (use SSH keys). |
| `enable_system_identity` | bool | `false` | Assign a system-assigned managed identity. |
| `enable_boot_diagnostics` | bool | `true` | Enable boot diagnostics. |
| `enable_telemetry` | bool | `true` | AVM telemetry. |

---

## Common Image References

### Ubuntu 22.04 LTS (default)

```hcl
image_publisher = "Canonical"
image_offer     = "0001-com-ubuntu-server-jammy"
image_sku       = "22_04-lts-gen2"
os_type         = "Linux"
```

### Ubuntu 24.04 LTS

```hcl
image_publisher = "Canonical"
image_offer     = "ubuntu-24_04-lts"
image_sku       = "server"
os_type         = "Linux"
```

### Windows Server 2022 Datacenter

```hcl
image_publisher = "MicrosoftWindowsServer"
image_offer     = "WindowsServer"
image_sku       = "2022-Datacenter"
os_type         = "Windows"
disable_password_auth = false
```

### Windows Server 2019 Datacenter

```hcl
image_publisher = "MicrosoftWindowsServer"
image_offer     = "WindowsServer"
image_sku       = "2019-Datacenter"
os_type         = "Windows"
disable_password_auth = false
```

Find more images:

```bash
az vm image list --output table
az vm image list --publisher Canonical --all --output table
```

---

## Remote State Setup

If you don't have an Azure Storage Account for Terraform state, create one:

```bash
# Variables
RG="rg-tfstate"
SA="satfstate$(openssl rand -hex 4)"   # must be globally unique, 3-24 lowercase chars
CONTAINER="tfstate"
LOCATION="uksouth"

# Create resources
az group create --name $RG --location $LOCATION
az storage account create \
  --name $SA \
  --resource-group $RG \
  --location $LOCATION \
  --sku Standard_LRS \
  --kind StorageV2 \
  --min-tls-version TLS1_2 \
  --allow-blob-public-access false

az storage container create \
  --name $CONTAINER \
  --account-name $SA \
  --auth-mode login

echo "Storage account: $SA"
echo "Container:       $CONTAINER"
echo "Resource group:  $RG"
```

Then initialise Terraform with backend config overrides (no hardcoded values in
`main.tf`):

```bash
terraform init \
  -backend-config="resource_group_name=$RG" \
  -backend-config="storage_account_name=$SA" \
  -backend-config="container_name=$CONTAINER" \
  -backend-config="key=<vm-name>.terraform.tfstate"
```

---

## CI/CD with GitHub Actions

Three workflows are included:

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| `terraform-plan.yml` | Pull request to `main` | Validates, formats-checks, and plans changed VMs. Posts the plan as a PR comment. |
| `terraform-apply.yml` | Push / merge to `main` | Applies changes to any VM directories modified in the merge commit. |
| `terraform-destroy.yml` | Manual (`workflow_dispatch`) | Destroys a specified VM. Requires typing `DESTROY` to confirm. |

### GitHub Secrets required

Configure these in **Settings → Secrets and variables → Actions**:

| Secret | Value |
|--------|-------|
| `AZURE_CLIENT_ID` | App registration / managed identity Client ID |
| `AZURE_TENANT_ID` | Azure AD Tenant ID |
| `AZURE_SUBSCRIPTION_ID` | Target subscription ID |
| `TFSTATE_RESOURCE_GROUP` | Resource group of the state storage account |
| `TFSTATE_STORAGE_ACCOUNT` | Storage account name |
| `TFSTATE_CONTAINER` | Blob container name (e.g. `tfstate`) |

### OIDC / Workload Identity Federation setup

The workflows use OIDC – no client secrets are stored in GitHub.

```bash
# Create an app registration
APP_ID=$(az ad app create --display-name "github-terraform-avm-azurevm" \
  --query appId -o tsv)

SP_ID=$(az ad sp create --id $APP_ID --query id -o tsv)

# Assign Contributor on the target subscription
az role assignment create \
  --assignee $APP_ID \
  --role Contributor \
  --scope /subscriptions/<subscription-id>

# Add federated credentials for pull_request and main branch
az ad app federated-credential create --id $APP_ID --parameters '{
  "name": "github-pr",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:<org>/<repo>:pull_request",
  "audiences": ["api://AzureADTokenExchange"]
}'

az ad app federated-credential create --id $APP_ID --parameters '{
  "name": "github-main",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:<org>/<repo>:ref:refs/heads/main",
  "audiences": ["api://AzureADTokenExchange"]
}'

echo "AZURE_CLIENT_ID: $APP_ID"
```

Store `$APP_ID` as the `AZURE_CLIENT_ID` secret in GitHub.

---

## Destroying Resources

### Manually (local)

```bash
cd infrastructure/virtual-machines/<vm-name>
terraform destroy
```

### Via GitHub Actions

1. Go to **Actions → Terraform Destroy → Run workflow**
2. Enter the VM directory path, e.g. `infrastructure/virtual-machines/example-vm`
3. Type `DESTROY` in the confirmation field
4. Click **Run workflow**

---

## Contributing

1. Fork the repository and create a feature branch
2. Copy `templates/vm/` to add a new VM, or modify an existing one
3. Open a pull request – the plan workflow will run automatically
4. Merge after review – the apply workflow deploys the changes
