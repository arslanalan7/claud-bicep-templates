# Azure Monitoring Onboarding (AMA + DCR)

This template is the **onboarding layer** for the Azure Monitoring Foundation.

Its purpose is to **attach existing workloads (VMs)** to a pre-created monitoring foundation by:
- Installing Azure Monitor Agent (AMA)
- Associating the VM with the correct Data Collection Rule (DCR)

This template is intentionally **separated from the foundation deployment** to keep responsibilities clear and deployments safe.

---

## What This Template Does

For each target Virtual Machine, this onboarding template:

- Installs **Azure Monitor Agent (AMA)**
  - `AzureMonitorWindowsAgent` for Windows
  - `AzureMonitorLinuxAgent` for Linux
- Creates a **Data Collection Rule Association**
  - Baseline or Verbose
  - Windows or Linux
- Does **not** create or modify:
  - Log Analytics Workspace
  - Data Collection Rules
  - Resource Groups

This ensures:
- No accidental changes to shared monitoring infrastructure
- Safe, incremental onboarding of workloads

---

## Architecture Overview

- **Scope:** Subscription
- **Execution model:**
  - Subscription-scope orchestrator (`main.bicep`)
  - Resource Group–scoped onboarding module per VM
- **Association model:**
  - DCR associations are created **under the VM scope**
  - The target resource is defined by `scope`, not by a `resourceId` property

---

## Prerequisites

Before using this template, the following must already exist:

- Log Analytics Workspace
- Data Collection Rules:
  - Windows baseline
  - Windows verbose
  - Linux baseline
  - Linux verbose

These are expected to be created by the **Monitoring Foundation** template.

---

## Parameters Overview

| Name | Description | Example |
|----|----|----|
| `location` | Azure region (used for AMA extension deployment) | `westeurope` |
| `dcrWindowsBaselineId` | Resource ID of Windows baseline DCR | `/subscriptions/.../dcr-windows-baseline` |
| `dcrWindowsVerboseId` | Resource ID of Windows verbose DCR | `/subscriptions/.../dcr-windows-verbose` |
| `dcrLinuxBaselineId` | Resource ID of Linux baseline DCR | `/subscriptions/.../dcr-linux-baseline` |
| `dcrLinuxVerboseId` | Resource ID of Linux verbose DCR | `/subscriptions/.../dcr-linux-verbose` |
| `defaultMode` | Default collection mode if not specified per VM | `baseline` |
| `allowVerbose` | Guardrail to disable verbose mode globally | `true` |
| `targets` | List of VMs to onboard | see example below |

---

## Targets Parameter Format

Each VM is defined explicitly to avoid ambiguity and support multiâ€“resource group scenarios.

```json
{
  "rgName": "rg-app-prod",
  "vmName": "vm-app-01",
  "osType": "windows",
  "mode": "baseline"
}
```

### Fields

- `rgName` - Resource Group where the VM exists
- `vmName` - Virtual Machine name
- `osType` - `windows` or `linux`
- `mode` *(optional)* - `baseline` or `verbose`
  - If omitted, `defaultMode` is used
  - If `allowVerbose = false`, verbose is forced to baseline

---

## Example Deployment

### What-if

```bash
az deployment sub what-if \
  --name monitoring-onboarding-whatif \
  --location westeurope \
  --template-file main.bicep \
  --parameters main.parameters.json
```

### Deploy

```bash
az deployment sub create \
  --name monitoring-onboarding \
  --location westeurope \
  --template-file main.bicep \
  --parameters main.parameters.json
```

---

## Post-Deployment Validation

### 1. Verify AMA Extension

```bash
az vm extension show \
  -g <resource-group> \
  --vm-name <vm-name> \
  -n AzureMonitorLinuxAgent \
  --query "{name:name, provisioningState:provisioningState}" -o table
```

(Use `AzureMonitorWindowsAgent` for Windows VMs.)

---

### 2. Verify DCR Association

```bash
SUB=$(az account show --query id -o tsv)
VM_ID=$(az vm show -g <RG_NAME> -n <VM_NAME> --query id -o tsv)

az rest --method get \
  --url "https://management.azure.com${VM_ID}/providers/Microsoft.Insights/dataCollectionRuleAssociations?api-version=2021-09-01-preview" \
  --query "value[].{name:name, dcr:properties.dataCollectionRuleId}" -o table
```

---

### 3. Verify Data in Log Analytics

```kusto
Perf
| where TimeGenerated > ago(30m)
| summarize count() by Computer, ObjectName
```

---

## Design Principles

- **Foundation vs Onboarding separation**
- **Idempotent deployments**
- **No implicit resource discovery**
- **Explicit and auditable VM onboarding**
- **Cost-aware baseline vs verbose collection**

---

## Rollback / Removal

To remove monitoring from a VM:
- Remove the DCR association
- Remove the AMA extension (optional)

No changes are required in the foundation template.

---

## Contribution

This template is intentionally simple and modular.

Suggestions, improvements, and pull requests are welcome:
- Additional guardrails
- Tag-based onboarding
- Environment-based defaults
- PaaS onboarding extensions

---

## Disclaimer

This template provides a **reference architecture** for Azure Monitoring onboarding.
It should be reviewed and adapted to organizational standards before production use.
