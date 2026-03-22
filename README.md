# Azure Verified Modules – Virtual Machine Lab

A hands-on lab showing how to deploy Azure Virtual Machines using the
[Azure Verified Module (AVM) for Compute: Virtual Machine](https://registry.terraform.io/modules/Azure/avm-res-compute-virtualmachine/azurerm).

VMs are grouped by business unit (BU) under `infrastructure/<bu>/virtual-machines/`.
Adding a VM means adding one `.tf` file to the relevant BU folder. Adding a new BU
means adding one folder. Everything else — planning, applying, state management —
is handled by the CI/CD workflows.

---

## Table of Contents

1. [What is an Azure Verified Module?](#what-is-an-azure-verified-module)
2. [Repository Layout](#repository-layout)
3. [Getting Started](#getting-started)
4. [Adding a New VM](#adding-a-new-vm)
5. [Adding a New Business Unit](#adding-a-new-business-unit)
6. [CI/CD with GitHub Actions](#cicd-with-github-actions)
7. [Variable Reference](#variable-reference)
8. [Common Image References](#common-image-references)
9. [Scaling Strategies](#scaling-strategies)
10. [Contributing](#contributing)

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
│   └── example/                    # One folder per business unit (BU)
│       └── virtual-machines/       # Terraform root module for this BU's VMs
│           ├── providers.tf        # Terraform version, providers, empty backend block
│           ├── variables.tf        # Shared variables (location, environment, tags)
│           ├── outputs.tf          # Outputs for all VMs in this BU
│           ├── example-vm.tf       # One file per VM – locals + child module call
│           └── env/
│               ├── dev/
│               │   ├── dev.tfbackend   # Backend config for dev state file
│               │   └── dev.tfvars      # Shared variable values for dev
│               ├── test/
│               │   ├── test.tfbackend
│               │   └── test.tfvars
│               └── prod/
│                   ├── prod.tfbackend
│                   └── prod.tfvars
│
├── modules/
│   └── vm/                         # Shared child module – all resource logic lives here
│       ├── main.tf                 # Resource group, AVM vnet module, AVM VM module
│       ├── variables.tf            # Inputs: name, environment, location, tags, config
│       └── outputs.tf              # resource_id, name, private_ip
│
├── templates/
│   └── vm.tf                       # Copy to infrastructure/<bu>/virtual-machines/<vm-name>.tf
│
├── .gitignore
├── LICENSE
└── README.md
```

**One file per VM. One folder per business unit. One shared child module for all resource logic.**

Each `<vm-name>.tf` file contains only a `locals` block (pure VM-specific data) and a
single call to the shared `modules/vm` child module. The child module owns the resource
group, virtual network, and VM — keeping per-VM files to ~30 lines of config, with no
infrastructure boilerplate to copy.

Each BU has its own Terraform root module (`infrastructure/<bu>/virtual-machines/`),
its own state file, and its own Azure subscription. The `env/` folder provides the
backend location and variable values per environment tier. Subscription IDs are kept
in the `SUBSCRIPTION_MAP` Actions variable on each GitHub environment and injected at
runtime — no per-BU GitHub environment setup is needed when adding a new BU.

---

## Getting Started

### 1. Clone the repository

```bash
git clone https://github.com/<your-org>/terraform-avm-azurevm.git
cd terraform-avm-azurevm
```

### 2. Fill in the variable files

Edit each `env/<env>/<env>.tfvars` file with the correct location and tags
for that environment:

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

> `subscription_id` is **not** in the tfvars file — it is read from
> the `SUBSCRIPTION_MAP` Actions variable on the target GitHub environment
> and injected into Terraform as `ARM_SUBSCRIPTION_ID`.

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

### 4. Add the BU to SUBSCRIPTION_MAP

In **Settings → Environments → \<environment\> → Variables**, add or update the
`SUBSCRIPTION_MAP` variable on each GitHub environment:

**`infra-nonprod`**
```json
{
  "example":   {"dev": "<dev-subscription-id>",  "test": "<test-subscription-id>"},
  "<new-bu>":  {"dev": "<dev-subscription-id>",  "test": "<test-subscription-id>"}
}
```

**`infra-prod`**
```json
{
  "example":   {"prod": "<prod-subscription-id>"},
  "<new-bu>":  {"prod": "<prod-subscription-id>"}
}
```

The workflow resolves the subscription ID from the environment-scoped variable at
runtime. Prod subscription IDs are only accessible to jobs running in `infra-prod`.

### 5. Configure GitHub environments and secrets

See [CI/CD with GitHub Actions](#cicd-with-github-actions) for the two required
GitHub environments, their secrets, and OIDC requirements. This is a one-time
setup — adding new BUs requires no further GitHub environment configuration.

### 6. Push a branch

Push to any non-main branch and the workflow deploys to **dev** automatically.
Open a PR to plan and apply to **test**. Merge to main to deploy to
**prod** (pending reviewer approval).

---

## Adding a New VM

```bash
# 1. Copy the template into the relevant BU folder
cp templates/vm.tf infrastructure/<bu>/virtual-machines/<new-vm-name>.tf

# 2. Replace all occurrences of <vm-name> and <vm_name> in the new file
#    <vm-name>  → kebab-case name used in Azure resource names  (e.g. web-server)
#    <vm_name>  → snake_case name used in HCL identifiers       (e.g. web_server)

# 3. Adjust the locals block – size, image, CIDRs, etc.

# 4. Add the three output blocks shown at the bottom of the template to outputs.tf
```

The resulting file is ~30 lines: a `locals` block with VM-specific data and a single
`module` call. All resource and networking logic is handled by `modules/vm`.

To make the VM reachable, set `enable_public_ip = true` in the locals block. This
attaches an AVM-managed public IP and creates an AVM-managed NSG that opens SSH (Linux)
or RDP (Windows). Restrict `allowed_cidrs` to known IPs rather than the default `["*"]`.

Resource names are derived automatically from the VM name and environment:

| Resource | Name pattern |
|----------|-------------|
| Resource group | `rg-<vm-name>-<env>` |
| Virtual network | `vnet-<vm-name>-<env>` |
| VM | `<vm-name>-<env>` |

Push the branch — the workflow detects the changed BU folder and plans/applies to dev.
No changes to workflows, backends, or variable files needed.

---

## Adding a New Business Unit

```bash
# 1. Create the BU folder structure
mkdir -p infrastructure/<bu-name>/virtual-machines/env/{dev,test,prod}

# 2. Copy the providers, variables, and outputs files from an existing BU
cp infrastructure/example/virtual-machines/providers.tf  infrastructure/<bu-name>/virtual-machines/
cp infrastructure/example/virtual-machines/variables.tf  infrastructure/<bu-name>/virtual-machines/
cp infrastructure/example/virtual-machines/outputs.tf    infrastructure/<bu-name>/virtual-machines/

# 3. Create env/<tier>/<tier>.tfbackend and env/<tier>/<tier>.tfvars for each tier
#    pointing to the BU's Azure Storage Account and subscription

# 4. Add at least one <vm-name>.tf file (copy templates/vm.tf)
```

Then add the BU's subscription IDs to the `SUBSCRIPTION_MAP` variable on each
GitHub environment (see [Getting Started step 4](#4-add-the-bu-to-subscription_map)).
No other GitHub environment or secret changes are needed. The trigger workflow
automatically detects pushes to the new folder and routes each tier to the
correct subscription via the map.

---

## CI/CD with GitHub Actions

Terraform is handled entirely by the workflows. You never need to run
`terraform init`, `plan`, or `apply` locally — just push, open a PR, or merge.

### How it works

| Workflow | Type | Purpose |
|----------|------|---------|
| `trigger-terraform-orchestration.yml` | Entry point | Detects changed BU folders; runs a matrix job per changed BU |
| `terraform-orchestration.yml` | Reusable | Chains plan → apply; apply is conditional on `run_tf_apply` |
| `terraform-analyze-and-plan.yml` | Reusable | validate, fmt-check, plan, upload artifact, post PR comment |
| `terraform-apply.yml` | Reusable | Download plan artifact, apply |

### Environment routing

The trigger workflow detects which `infrastructure/<bu>/virtual-machines` directories
changed, then runs the orchestration workflow once per changed BU. The tier and
GitHub environment are determined by the git event:

| Git event | Tier | GitHub environment | Apply? |
|-----------|------|--------------------|--------|
| Push to any non-main branch | `dev` | `infra-nonprod` | Yes |
| Pull request to `main` | `test` | `infra-nonprod` | Yes |
| Push / merge to `main` | `prod` | `infra-prod` | Yes — requires reviewer approval |

The subscription ID for each BU + tier combination is read from the `SUBSCRIPTION_MAP`
Actions variable on the target GitHub environment and does not come from GitHub secrets.

### GitHub Environments

Create exactly **two** environments in **Settings → Environments**:

| Environment | Used for | Entra tenant |
|-------------|----------|--------------|
| `infra-nonprod` | `dev` and `test` tiers | dev/test tenant |
| `infra-prod` | `prod` tier | prod tenant |

Add a required reviewer to `infra-prod` to gate production applies behind a manual
approval. No new environments are needed when adding BUs.

### GitHub Secrets

Set these secrets on **each** environment in **Settings → Environments → \<environment\> → Secrets**:

| Secret | Value |
|--------|-------|
| `AZURE_CLIENT_ID` | App Registration Client ID for the service principal (used for OIDC) |
| `AZURE_TENANT_ID` | Entra tenant ID for this environment |
| `VM_ADMIN_PASSWORD` | Optional – admin password for VMs with password auth enabled. When absent, a password or SSH key is auto-generated by the AVM module. Rotating this secret and running Terraform resets the VM password. |
| `TF_LOG_LEVEL` | Optional – Terraform log verbosity (`INFO`, `DEBUG`, or blank) |

### GitHub Variables

Set this variable on **each** environment in **Settings → Environments → \<environment\> → Variables**:

| Variable | Value |
|----------|-------|
| `SUBSCRIPTION_MAP` | JSON object mapping BU names to the subscription IDs used by this environment (see [Getting Started step 4](#4-add-the-bu-to-subscription_map)) |

Subscription IDs are not secrets — they are stored as plain Actions variables,
scoped per environment so prod IDs are never accessible to non-prod jobs.

### OIDC authentication

Workflows authenticate via OIDC — no client secrets are stored in GitHub.
You need one Azure App Registration per Entra tenant with a service principal that
has Contributor (or equivalent) access across all BU subscriptions in that tenant.
Configure federated credentials for each GitHub environment
(`repo:<org>/<repo>:environment:infra-nonprod` and `...:infra-prod`). See the
[Microsoft docs on workload identity federation](https://learn.microsoft.com/en-us/entra/workload-id/workload-identity-federation-create-trust)
for setup.

---

## Variable Reference

Shared variables defined in `variables.tf` and set in `env/<env>/<env>.tfvars`.
VM-specific settings (size, image, CIDRs) are defined as locals inside each
`<vm-name>.tf` file and passed to the `modules/vm` child module. Resource names
(`rg-*`, `vnet-*`, VM name) are derived from the `name` argument and `var.environment`.

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `location` | string | `"uksouth"` | Azure region for all resources. |
| `environment` | string | – | **Required.** `dev`, `test`, or `prod`. Used to construct all resource names. |
| `tags` | map(string) | `{}` | Tags applied to all resources. |

> `subscription_id` is not a Terraform variable — it is provided to the azurerm
> provider via the `ARM_SUBSCRIPTION_ID` environment variable, which the workflow
> resolves from `SUBSCRIPTION_MAP` (GitHub environment variable) using the BU name and tier.

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
subscriptions, add entries for each category to the `SUBSCRIPTION_MAP` variable on
each GitHub environment. The workflow resolves the correct subscription ID at runtime
from the environment-scoped variable — no additional secrets or environments are needed.

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
2. To add a VM: copy `templates/vm.tf` into the relevant BU folder, adjust the locals block (see [Adding a New VM](#adding-a-new-vm))
3. To add a BU: create the folder structure and update `SUBSCRIPTION_MAP` on each GitHub environment (see [Adding a New Business Unit](#adding-a-new-business-unit))
4. Open a pull request — the test environment plan and apply run automatically
5. Merge after review — the prod workflow fires and waits for approval before applying
