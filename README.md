# Azure Verified Modules – Virtual Machine Lab

A hands-on lab showing how to deploy Azure Virtual Machines using the
[Azure Verified Module (AVM) for Compute: Virtual Machine](https://registry.terraform.io/modules/Azure/avm-res-compute-virtualmachine/azurerm).

All VMs live in a single Terraform root module under `infrastructure/virtual-machines/`.
Adding a VM means adding one `.tf` file. Everything else — planning, applying,
state management — is handled by the CI/CD workflows.

---

## Table of Contents

1. [What is an Azure Verified Module?](#what-is-an-azure-verified-module)
2. [Repository Layout](#repository-layout)
3. [Getting Started](#getting-started)
4. [Adding a New VM](#adding-a-new-vm)
5. [CI/CD with GitHub Actions](#cicd-with-github-actions)
6. [Variable Reference](#variable-reference)
7. [Common Image References](#common-image-references)
8. [Scaling Strategies](#scaling-strategies)
9. [Contributing](#contributing)

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
│   └── virtual-machines/           # Single Terraform root module – all VMs live here
│       ├── providers.tf            # Terraform version, providers, empty backend block
│       ├── variables.tf            # Shared variables (subscription_id, location, environment, tags)
│       ├── outputs.tf              # Outputs for all VMs
│       ├── example-vm.tf           # One file per VM – add a new .tf file to add a VM
│       └── env/
│           ├── dev/
│           │   ├── dev.tfbackend   # Backend config for dev state file
│           │   └── dev.tfvars      # Shared variable values for dev
│           ├── test/
│           │   ├── test.tfbackend
│           │   └── test.tfvars
│           └── prod/
│               ├── prod.tfbackend
│               └── prod.tfvars
│
├── templates/
│   └── vm.tf                       # Copy to infrastructure/virtual-machines/<vm-name>.tf
│
├── .gitignore
├── LICENSE
└── README.md
```

**One file per VM, one Terraform root module for all VMs.**
VM-specific values (name, size, image, networking CIDRs) are hardcoded as locals
inside each `<vm-name>.tf` file, with `var.environment` used to construct
environment-aware resource names. The shared `env/` folder provides the backend
location and cross-cutting values (subscription ID, tags) per environment.

---

## Getting Started

### 1. Clone the repository

```bash
git clone https://github.com/<your-org>/terraform-avm-azurevm.git
cd terraform-avm-azurevm
```

### 2. Fill in the variable files

Edit each `env/<env>/<env>.tfvars` file with the correct location and tags
for that environment. The subscription ID is set as a GitHub secret per environment — not here:

```hcl
# env/dev/dev.tfvars
location    = "uksouth"
environment = "dev"

tags = {
  environment = "dev"
  managed_by  = "Terraform"
  project     = "virtual-machines"
}
```

> `subscription_id` is **not** in the tfvars file — it is supplied automatically
> via the `AZURE_SUBSCRIPTION_ID` GitHub secret, which the workflow exposes to
> Terraform as `ARM_SUBSCRIPTION_ID`.

> The `env/` files **are** committed to the repo — they contain non-sensitive
> configuration only. Never put passwords or secrets directly in these files.

### 3. Fill in the backend files

Edit each `env/<env>/<env>.tfbackend` with your Azure Storage Account details
(you need an existing Storage Account and container for Terraform remote state):

```hcl
# env/dev/dev.tfbackend
resource_group_name  = "rg-tfstate"
storage_account_name = "satfstate<unique-suffix>"
container_name       = "tfstate"
key                  = "virtual-machines-dev.terraform.tfstate"
```

### 4. Configure GitHub environments and secrets

See [CI/CD with GitHub Actions](#cicd-with-github-actions) for the full list of
required GitHub environments, secrets, and OIDC requirements.

### 5. Push a branch

Push to any non-main branch and the workflow deploys to **dev** automatically.
Open a PR to run a plan-only check against **test**. Merge to main to deploy to
**prod** (pending reviewer approval).

---

## Adding a New VM

```bash
# 1. Copy the template file
cp templates/vm.tf infrastructure/virtual-machines/<new-vm-name>.tf

# 2. Replace all occurrences of <vm-name> and <vm_name> in the file
#    <vm-name>  → kebab-case name used in Azure resource names  (e.g. web-server)
#    <vm_name>  → snake_case name used in HCL identifiers       (e.g. web_server)

# 3. Adjust the locals block – size, image, CIDR, etc.

# 4. Add matching output blocks to outputs.tf
#    (the template file shows the exact blocks to add as comments at the bottom)
```

Then push the branch — the workflow picks up the new file automatically and
plans/applies to dev. No changes to workflows, backends, or variable files needed.

---

## CI/CD with GitHub Actions

Terraform is handled entirely by the workflows. You never need to run
`terraform init`, `plan`, or `apply` locally — just push, open a PR, or merge.

### How it works

| Workflow | Type | Purpose |
|----------|------|---------|
| `trigger-terraform-orchestration.yml` | Entry point | Fires on changes to `infrastructure/**`; routes to dev/test/prod jobs |
| `terraform-orchestration.yml` | Reusable | Chains plan → apply; apply is conditional on `run_tf_apply` |
| `terraform-analyze-and-plan.yml` | Reusable | validate, fmt-check, plan, upload artifact, post PR comment |
| `terraform-apply.yml` | Reusable | Download plan artifact, apply |

### Environment routing

| Git event | Environment | Apply? |
|-----------|-------------|--------|
| Push to any non-main branch | `dev` | Yes |
| Pull request to `main` | `test` | Yes |
| Push / merge to `main` | `prod` | Yes — requires reviewer approval |

### GitHub Environments

Create three environments in **Settings → Environments**: `dev`, `test`, `prod`.
Add a required reviewer to `prod` to gate production applies behind a manual approval.

### GitHub Secrets

Set these secrets on each environment in **Settings → Secrets and variables → Actions**:

| Secret | Value |
|--------|-------|
| `AZURE_CLIENT_ID` | App Registration Client ID (used for OIDC) |
| `AZURE_TENANT_ID` | Azure AD Tenant ID |
| `AZURE_SUBSCRIPTION_ID` | Target subscription ID |
| `TF_LOG_LEVEL` | Optional – Terraform log verbosity (`INFO`, `DEBUG`, or blank) |

### OIDC authentication

Workflows authenticate via OIDC — no client secrets are stored in GitHub.
You need an Azure App Registration with a service principal, Contributor role
on the target subscription(s), and federated credentials configured for
branches, pull requests, and main. See the
[Microsoft docs on workload identity federation](https://learn.microsoft.com/en-us/entra/workload-id/workload-identity-federation-create-trust)
for setup.

---

## Variable Reference

Shared variables defined in `variables.tf` and set in `env/<env>/<env>.tfvars`.
VM-specific settings (name, size, image, CIDRs) are hardcoded as locals inside
each `<vm-name>.tf` file.

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `location` | string | `"uksouth"` | Azure region for all resources. |
| `environment` | string | – | **Required.** `dev`, `test`, or `prod`. Used to construct all resource names. |
| `tags` | map(string) | `{}` | Tags applied to all resources. |

> `subscription_id` is not a Terraform variable — it is provided to the azurerm
> provider via the `ARM_SUBSCRIPTION_ID` environment variable, set by the workflow
> from the `AZURE_SUBSCRIPTION_ID` GitHub secret.

---

## Common Image References

### Ubuntu 22.04 LTS (default)

```hcl
image = {
  publisher = "Canonical"
  offer     = "0001-com-ubuntu-server-jammy"
  sku       = "22_04-lts-gen2"
}
os_type = "Linux"
```

### Ubuntu 24.04 LTS

```hcl
image = {
  publisher = "Canonical"
  offer     = "ubuntu-24_04-lts"
  sku       = "server"
}
os_type = "Linux"
```

### Windows Server 2022 Datacenter

```hcl
image = {
  publisher = "MicrosoftWindowsServer"
  offer     = "WindowsServer"
  sku       = "2022-Datacenter"
}
os_type               = "Windows"
disable_password_auth = false
```

### Windows Server 2019 Datacenter

```hcl
image = {
  publisher = "MicrosoftWindowsServer"
  offer     = "WindowsServer"
  sku       = "2019-Datacenter"
}
os_type               = "Windows"
disable_password_auth = false
```

---

## Scaling Strategies

This repo starts with a single Terraform root module for all VMs. As your fleet
grows, here are the natural progression points.

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

The trigger workflow has one static job per category — exactly the same pattern
used for dev/test/prod today. Adding a category = add one job to the trigger.

```
infrastructure/
├── web-servers/      ← terraform root, own state
├── build-agents/     ← terraform root, own state
└── jump-hosts/       ← terraform root, own state
```

**Use when:** The fleet is large enough that category-level isolation is
valuable, but still managed by one team.

**Pros:** Independent state per category; category-level blast radius.

**Cons:** Adding a category requires a small workflow change.

**Multiple subscriptions:** If different categories target different Azure
subscriptions, add a subscription secret per category to each GitHub environment
(e.g. `AZURE_SUBSCRIPTION_ID_WEB_SERVERS`, `AZURE_SUBSCRIPTION_ID_BUILD_AGENTS`)
and reference the appropriate secret in each workflow job.

---

### Strategy 3 – Terragrunt

[Terragrunt](https://terragrunt.gruntwork.io/) handles multi-directory
orchestration natively. The workflow calls `terragrunt run-all plan` and it
discovers all changed modules automatically — no detection logic required at
any scale.

**Use when:** Many categories or sub-teams; avoiding per-directory workflow jobs.

**Pros:** Fully dynamic; handles module dependencies; scales to any number of directories.

**Cons:** Additional tool to learn and maintain.

---

## Contributing

1. Fork the repository and create a feature branch
2. Copy `templates/vm.tf` to add a new VM, adjust the locals block
3. Open a pull request — the test environment plan runs automatically
4. Merge after review — the prod workflow fires and waits for approval before applying
