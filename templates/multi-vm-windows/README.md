# Multi VM Windows (Azure Bicep)

This template deploys **one or more Windows Server virtual machines** in Azure.

It is designed to be:
- Simple
- Reusable
- Easy to adapt for different subscriptions

---

## What this template creates

- 1+ Windows Server VM(s)
- Virtual Network & Subnet
- Network Security Group (RDP rule)
- Public IP for each VM
- Boot diagnostics storage account

VM count is controlled via a parameter.

---

## Parameters

| Name | Description | Example |
|----|----|----|
| `vmCount` | Number of virtual machines | `1` |
| `vmName` | VM name prefix | `myvm` |
| `dnsLabelPrefix` | Public DNS name prefix | `myvm` |
| `vmSize` | Azure VM size | `Standard_B1s` |
| `location` | Azure region | `westeurope` |
| `adminUsername` | VM admin username | `azureadmin` |
| `adminPassword` | VM admin password | **required** |

---

## Deploy instructions

### 1) Copy parameters file
```bash```
cp parameters.example.json parameters.json

### 1) Copy parameters file
```bash```
cp parameters.example.json parameters.json

### 2) Edit parameters

Set a strong password in parameters.json.

### 3) Run what-if
```bash
az deployment group what-if \
  -g <resource-group> \
  -f main.bicep \
  -p main.parameters.json
```

  ### 4) Deploy
```bash
az deployment group create \
  -g <resource-group> \
  -f main.bicep \
  -p main.parameters.json
```

## Security notes

RDP (3389) is allowed by default for simplicity

For real environments, restrict access to your IP address

Never commit real passwords to source control

## Notes

This template is intended as a starting point.
You are expected to adapt networking, security, and sizing for production use.


