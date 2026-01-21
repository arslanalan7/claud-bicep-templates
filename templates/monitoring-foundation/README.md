# Azure Monitoring Foundation (Bicep)

This repository provides a **production-ready Azure Monitoring Foundation** built with **Bicep**.  
It deploys a **Log Analytics Workspace** and a standardized set of **Windows and Linux Data Collection Rules (DCRs)** designed to balance **low cost**, **high signal**, and **incident-driven observability**.

The goal of this foundation is to establish a **stable monitoring platform** that workloads (VMs and other resources) can later be onboarded to without modifying the core monitoring infrastructure.

---

## ✨ What This Template Does

This Bicep template deploys:

- **1 Log Analytics Workspace**
  - Configurable retention
  - PerGB2018 pricing model
  - Can be created or reused (existing workspace supported)

- **4 Data Collection Rules (DCRs)**
  - Windows – Baseline
  - Windows – Verbose
  - Linux – Baseline
  - Linux – Verbose

### DCR Design Philosophy

- **Baseline DCRs**
  - Always-on
  - Low ingestion cost
  - Collect only high-value signals (KPI + first-pass RCA)

- **Verbose DCRs**
  - Used during incidents or investigations
  - Higher signal density
  - Applied selectively to affected resources

This separation allows you to **switch verbosity at the resource level** without redeploying the monitoring foundation.

---

## 🎯 What This Template Intentionally Does NOT Do

This is a **foundation** package. It does **not**:

- Install Azure Monitor Agent (AMA) on VMs
- Associate VMs or other resources with DCRs
- Configure Diagnostic Settings on PaaS resources
- Create alerts, workbooks, or dashboards

Those responsibilities belong to **onboarding** and **operations** layers, which should evolve independently from the foundation.

---

## 🧱 Architecture Overview

Subscription
└── Resource Group (Monitoring)
├── Log Analytics Workspace
├── DCR - Windows Baseline
├── DCR - Windows Verbose
├── DCR - Linux Baseline
└── DCR - Linux Verbose


- All monitoring resources live in a **dedicated monitoring resource group**
- Deployment is executed at **subscription scope**
- Individual modules run at **resource group scope**

---

## 📊 What Logs and Metrics Are Collected?

### Windows Baseline
- Event Logs:
  - System + Application
  - Levels: Critical, Error
- Performance Counters:
  - CPU usage
  - Available memory
  - Disk free space (per disk, absolute + percentage)

### Windows Verbose
- Event Logs:
  - System + Application
  - Levels: Critical, Error, Warning
- Same performance counters with higher sampling frequency

---

### Linux Baseline (Ubuntu 24.04 LTS compatible)
- Syslog:
  - Levels: Warning and above
  - Facilities: auth, authpriv, kern, daemon, syslog, user
- Performance Counters:
  - CPU usage
  - Available memory
  - Disk free space per filesystem (absolute + percentage)

### Linux Verbose
- Syslog:
  - Levels: Info and above
- Same performance counters with higher sampling frequency

> Disk metrics use a normalized `LogicalDisk(*)` abstraction to keep Windows and Linux semantically aligned.

---

## 🚀 How to Use

### Prerequisites
- Azure CLI installed and authenticated
- Target resource group already exists
- Required resource providers registered:
  - `Microsoft.OperationalInsights`
  - `Microsoft.Insights`

---

### Validate with What-If (Recommended)

Because this is a **subscription-scope deployment**, always use `deployment sub`.

```bash
az deployment sub what-if \
  --name monitoring-foundation-test \
  --location westeurope \
  --template-file main.bicep \
  --parameters main.parameters.json
```

### Deploy
```bash
az deployment sub create \
  --name monitoring-foundation \
  --location westeurope \
  --template-file main.bicep \
  --parameters main.parameters.json
```

### ⚙️ Parameters Overview

| Name | Description | Example |
|------|------------|---------|
| `monitoringRgName` | Resource group where monitoring resources will be deployed | `rg-monitoring-prod` |
| `location` | Azure region for monitoring resources | `westeurope` |
| `existingWorkspaceResourceId` | Existing Log Analytics Workspace resource ID. If provided, a new workspace will NOT be created | `/subscriptions/xxxx/resourceGroups/rg-monitoring-prod/providers/Microsoft.OperationalInsights/workspaces/log-prod-ws` |
| `workspaceName` | Log Analytics Workspace name (used only when creating) | `log-prod-ws` |
| `retentionInDays` | Log retention period in days | `30` |
| `dcrWindowsBaseName` | Base name for Windows Data Collection Rules | `dcr-prod-windows` |
| `dcrLinuxBaseName` | Base name for Linux Data Collection Rules | `dcr-prod-linux` |
| `perfSamplingBaselineSeconds` | Sampling frequency for baseline performance counters (seconds) | `30` |
| `perfSamplingVerboseSeconds` | Sampling frequency for verbose performance counters (seconds) | `15` |


> In production environments, it is strongly recommended to provide
> `existingWorkspaceResourceId` to avoid accidental creation or modification
> of shared Log Analytics workspaces.



## ⚠️ Important Notes & Best Practices

### Workspace Creation

If existingWorkspaceResourceId is empty, the template will attempt to create a workspace.

If a workspace with the same name already exists in the target RG, deployment will fail.

This is intentional (“fail fast”) and avoids accidental adoption of shared workspaces.

### Production Recommendation

In production environments, always provide existingWorkspaceResourceId.

Treat the workspace as a shared platform resource with its own lifecycle.

### Linux Disk Metrics

Filesystems like /, /var, /data are collected individually.

Temporary filesystems (e.g. /run, overlay) may appear.

Alerts and dashboards should filter relevant mount points explicitly.

## 🔄 Typical Lifecycle

Deploy Monitoring Foundation (this repo)

Deploy Onboarding templates

Install AMA

Associate resources with baseline DCRs

During incidents:

Temporarily associate selected resources with verbose DCRs

Revert to baseline after resolution

## 🧠 Design Principles

Low noise by default

High RCA value

Cost-aware

Explicit ownership

Idempotent deployments

Foundation vs onboarding separation

## 📌 Extending This Foundation

### Common next steps:

Add Action Groups and alert rules

Add Diagnostic Settings modules for PaaS resources

Add Workbooks and dashboards

Integrate with Azure Policy (AMA enforcement)

Integrate with Microsoft Sentinel

This foundation is designed to support all of the above without breaking changes.

## 📄 License / Usage

Use freely and adapt to your organizational standards.
Test changes in non-production environments before applying to production.

## 🤝 Contributions & Feedback

This project reflects a set of design decisions based on real-world Azure
monitoring challenges. It is not intended to be a one-size-fits-all solution.

Feedback, suggestions, and improvements are very welcome.

- Feel free to open issues for questions or design discussions
- Pull requests are welcome, especially for:
  - Additional log or metric ideas
  - Cost optimization improvements
  - Cross-platform consistency enhancements
  - Real-world production feedback

The goal is to evolve this foundation through shared experience.

---

# Azure Monitor DCR - Linux Syslog Forwarding (Ubuntu 24.04)

This repository contains Bicep templates for defining Data Collection Rules (DCR) in Azure Monitor.  
When deploying AMA (Azure Monitor Agent) on Linux VMs, by default only `auth` facility logs are forwarded to Log Analytics.  
On modern distributions such as **Ubuntu 24.04**, journald → rsyslog forwarding is not enabled by default, which means other facilities (`kern`, `daemon`, `user`, `syslog`) are not captured.

## 📌 Solution: Enable journald → rsyslog Forwarding

### 1. Add imjournal module to rsyslog configuration
Run the following commands on the VM to append the required lines to `/etc/rsyslog.conf`:

```bash
echo 'module(load="imjournal" PollingInterval="10")' | sudo tee -a /etc/rsyslog.conf
echo 'input(type="imjournal" StateFile="/var/lib/rsyslog/imjournal.state")' | sudo tee -a /etc/rsyslog.conf
```

### 2. Restart rsyslog service

```bash
sudo systemctl restart rsyslog
```

### 3. Validate configuration

```bash
rsyslogd -N1
```

This command tests the rsyslog configuration. If the imjournal module is successfully loaded, no errors will be reported.

### 4. Generate test logs

```bash
logger -p user.info "Test message from user facility"
logger -p kern.warning "Test message from kernel facility"
```

### 5. Verify in Log Analytics

Navigate to Log Analytics Workspace → Logs → Syslog table in the Azure Portal.
You should now see entries for facility=user and facility=kern, in addition to auth.
