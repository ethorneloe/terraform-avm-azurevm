# Azure Verified Modules – Virtual Machine Lab

A hands-on lab showing how to deploy Azure Virtual Machines using the
[Azure Verified Module (AVM) for Compute: Virtual Machine](https://registry.terraform.io/modules/Azure/avm-res-compute-virtualmachine/azurerm).

Each VM lives in its own folder under `infrastructure/virtual-machines/`, making
it easy to manage, diff, and deploy VMs independently across dev, test, and prod
environments.

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
10. [Scaling Strategies](#scaling-strategies)
11. [Destroying Resources](#destroying-resources)

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
│       ├── trigger-terraform-orchestration.yml  # Entry point – fires on infrastructure/ changes
│       ├── terraform-orchestration.yml          # Reusable – chains plan → apply
│       ├── terraform-analyze-and-plan.yml       # Reusable – validate, fmt, plan, post PR comment
│       └── terraform-apply.yml                  # Reusable – apply pre-approved plan
│
├── infrastructure/
│   └── virtual-machines/
│       └── example-vm/             # Reference VM configuration
│           ├── main.tf             # Resources (VNet, VM via AVM module)
│           ├── variables.tf        # All input variables with defaults
│           ├── outputs.tf          # VM ID, name, private IP
│           ├── providers.tf        # Terraform version, providers, empty backend block
│           └── env/
│               ├── dev/
│               │   ├── dev.tfbackend   # Backend config for dev state file
│               │   └── dev.tfvars      # Variable values for dev
│               ├── test/
│               │   ├── test.tfbackend
│               │   └── test.tfvars
│               └── prod/
│                   ├── prod.tfbackend
│                   └── prod.tfvars
│
├── templates/
│   └── vm/                         # Blank template – copy this for each new VM
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       ├── providers.tf
│       └── env/
│           ├── dev/  (dev.tfbackend, dev.tfvars)
│           ├── test/ (test.tfbackend, test.tfvars)
│           └── prod/ (prod.tfbackend, prod.tfvars)
│
├── .gitignore
├── LICENSE
└── README.md
```

**One folder = one VM.**
Each VM folder is a self-contained Terraform root module. Environment-specific
configuration (backend location, variable values) lives in the `env/` subfolder.
Backend credentials are never hardcoded – they are passed to `terraform init` at
runtime via `-backend-config`.

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

### 3. Fill in the environment variable files

Navigate to the example VM's dev environment:

```bash
cd infrastructure/virtual-machines/example-vm
```

Edit `env/dev/dev.tfvars` and fill in your values:

```hcl
subscription_id     = "00000000-0000-0000-0000-000000000000"
resource_group_name = "rg-example-vm-dev"
vm_name             = "example-vm-dev"
```

Edit `env/dev/dev.tfbackend` with your storage account details:

```hcl
resource_group_name  = "rg-tfstate"
storage_account_name = "satfstate<unique-suffix>"
container_name       = "tfstate"
key                  = "example-vm-dev.terraform.tfstate"
```

> The `env/` files **are** committed to the repo – they contain non-sensitive
> configuration. Never put passwords or subscription keys directly in these files.

### 4. Initialise Terraform

Pass the backend config file at init time (matches the pattern used in CI/CD):

```bash
terraform init -backend-config=env/dev/dev.tfbackend
```

### 5. Plan and apply

```bash
terraform plan -var-file=env/dev/dev.tfvars
terraform apply -var-file=env/dev/dev.tfvars
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
cd infrastructure/virtual-machines/<new-vm-name>

# 2. Fill in each environment's variable file
#    Replace all <placeholder> values in env/dev/dev.tfvars, env/test/test.tfvars, env/prod/prod.tfvars

# 3. Update each environment's backend key
#    env/dev/dev.tfbackend   → key = "<new-vm-name>-dev.terraform.tfstate"
#    env/test/test.tfbackend → key = "<new-vm-name>-test.terraform.tfstate"
#    env/prod/prod.tfbackend → key = "<new-vm-name>-prod.terraform.tfstate"

# 4. Initialise and deploy (dev environment example)
terraform init -backend-config=env/dev/dev.tfbackend
terraform plan  -var-file=env/dev/dev.tfvars
terraform apply -var-file=env/dev/dev.tfvars
```

Each VM has its own state file per environment, so VMs and environments are
completely independent of each other.

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
RG="rg-tfstate"
SA="satfstate$(openssl rand -hex 4)"   # must be globally unique, 3-24 lowercase chars
CONTAINER="tfstate"
LOCATION="uksouth"

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

echo "Storage account: $SA  →  use in *.tfbackend files"
```

Then update all `*.tfbackend` files in your VM's `env/` folders with the
storage account name and resource group.

---

## CI/CD with GitHub Actions

The workflow design mirrors [terraform-azurerm-law-dcr](https://github.com/ethorneloe/terraform-azurerm-law-dcr)
with four files following the same reusable-workflow pattern:

| Workflow | Type | Trigger | Purpose |
|----------|------|---------|---------|
| `trigger-terraform-orchestration.yml` | Entry point | Push / PR to `infrastructure/**` | Detects changed VM dirs, routes to dev/test/prod jobs |
| `terraform-orchestration.yml` | Reusable | `workflow_call` | Chains plan → apply; apply is conditional on `run_tf_apply` |
| `terraform-analyze-and-plan.yml` | Reusable | `workflow_call` | validate, fmt-check, plan, upload artifact, post PR comment |
| `terraform-apply.yml` | Reusable | `workflow_call` | Download plan artifact, apply |

### Environment routing

| Git event | Environment used | Apply? |
|-----------|-----------------|--------|
| Push to any non-main branch | `dev` | Yes |
| Pull request to `main` | `test` | No (plan only) |
| Push / merge to `main` | `prod` | Yes |

The `prod` GitHub environment should be configured with a **required reviewer**
protection rule so every production apply requires manual approval after the plan
is reviewed.

### GitHub Secrets required

Configure these in **Settings → Secrets and variables → Actions**:

| Secret | Value |
|--------|-------|
| `AZURE_CLIENT_ID` | App registration Client ID (used for OIDC) |
| `AZURE_TENANT_ID` | Azure AD Tenant ID |
| `AZURE_SUBSCRIPTION_ID` | Target subscription ID |
| `TF_LOG_LEVEL` | Optional – Terraform log verbosity (e.g. `INFO`, `DEBUG`, or leave blank) |

> Note: Unlike a simpler setup, the storage account for state is configured
> directly in each VM's `env/<env>/<env>.tfbackend` files, so no storage account
> secrets are needed in GitHub.

### GitHub Environments required

Create three GitHub environments (**Settings → Environments**): `dev`, `test`, `prod`.
Each environment must have the Azure OIDC secrets configured. Add a required
reviewer to `prod` to gate production applies behind a manual approval.

### OIDC / Workload Identity Federation setup

The workflows use OIDC – no client secrets are stored in GitHub.

```bash
APP_ID=$(az ad app create --display-name "github-terraform-avm-azurevm" \
  --query appId -o tsv)

az ad sp create --id $APP_ID

# Assign Contributor on the target subscription(s)
az role assignment create \
  --assignee $APP_ID \
  --role Contributor \
  --scope /subscriptions/<subscription-id>

# Federated credential for pull requests
az ad app federated-credential create --id $APP_ID --parameters '{
  "name": "github-pr",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:<org>/terraform-avm-azurevm:pull_request",
  "audiences": ["api://AzureADTokenExchange"]
}'

# Federated credential for main branch pushes
az ad app federated-credential create --id $APP_ID --parameters '{
  "name": "github-main",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:<org>/terraform-avm-azurevm:ref:refs/heads/main",
  "audiences": ["api://AzureADTokenExchange"]
}'

# Federated credential for non-main branch pushes (dev)
az ad app federated-credential create --id $APP_ID --parameters '{
  "name": "github-branches",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:<org>/terraform-avm-azurevm:ref:refs/heads/*",
  "audiences": ["api://AzureADTokenExchange"]
}'

echo "AZURE_CLIENT_ID=$APP_ID"
```

---

## Scaling Strategies

This repo starts with a single Terraform root module for all VMs. As your fleet
grows, here are the natural progression points and when to make each move.

### Strategy 1 – Single directory (current)

All VM configs live in one directory, one state file, one `terraform` run.

**Use when:** Small fleet, one team, straightforward changes.

**Pros:** No CI/CD detection logic needed; Terraform handles everything in one
run; a change to one VM file only affects that VM in the plan.

**Cons:** All VMs share a state lock (parallel applies are not possible); a
corrupted state affects all VMs.

---

### Strategy 2 – Split by category

Group VMs by function (e.g. `web-servers/`, `build-agents/`, `jump-hosts/`).
Each category is its own Terraform root module with its own state file.

The trigger workflow has one static job per category, each with a path condition
— exactly the same pattern used in `trigger-terraform-orchestration.yml` for
dev/test/prod today. Adding a category = add one job to the trigger.

```
infrastructure/
├── web-servers/      ← terraform root, own state
├── build-agents/     ← terraform root, own state
└── jump-hosts/       ← terraform root, own state
```

**Use when:** The fleet is large enough that category-level isolation is
valuable, but still managed by one team.

**Pros:** Independent state per category; category-level blast radius; no
dynamic detection needed.

**Cons:** Adding a category requires a small workflow change.

---

### Strategy 3 – Terragrunt

[Terragrunt](https://terragrunt.gruntwork.io/) is a thin wrapper around
Terraform that handles multi-directory orchestration natively. The workflow
calls `terragrunt run-all plan` and it discovers all changed modules
automatically — no detection logic required at any scale.

**Use when:** You have many categories or sub-teams and want to avoid
maintaining per-directory workflow jobs entirely.

**Pros:** Fully dynamic; handles dependencies between modules; scales to any
number of directories.

**Cons:** Additional tool to learn and maintain.

---

## Destroying Resources

### Manually (local)

```bash
cd infrastructure/virtual-machines/<vm-name>
terraform init   -backend-config=env/dev/dev.tfbackend
terraform destroy -var-file=env/dev/dev.tfvars
```

### Via the reusable workflow (workflow_dispatch)

You can trigger `terraform-orchestration.yml` directly from the GitHub Actions UI
(**Actions → Terraform Orchestration → Run workflow**) and pass:

- `environment`: `dev`, `test`, or `prod`
- `working_directory`: e.g. `infrastructure/virtual-machines/example-vm`
- `tfbackend_filepath`: e.g. `env/dev/dev.tfbackend`
- `tfvars_filepath`: e.g. `env/dev/dev.tfvars`
- `run_tf_apply`: `false` (plan only first, then confirm)

---

## Contributing

1. Fork the repository and create a feature branch
2. Copy `templates/vm/` to add a new VM, fill in the `env/` files
3. Open a pull request – the test environment plan runs automatically
4. Merge after review – the prod workflow fires and waits for approval before applying
