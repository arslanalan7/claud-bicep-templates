# claud-bicep-templates

This repository contains **reusable Azure Bicep templates** and **real-world infrastructure examples**.

The goal is to provide:
- Clean and understandable Bicep templates
- Safe defaults (no secrets in source control)
- Examples that can be reused across different Azure subscriptions

All templates are written with **real deployments** in mind, not just demos.

---

## Templates

### ▶ Multi VM Windows
**Path:** `templates/multi-vm-windows`

Creates one or more Windows Server virtual machines with:
- Virtual Network & Subnet
- Network Security Group
- Public IP per VM
- Boot diagnostics enabled
- Optional multi-VM support via parameters

➡️ [View template](templates/multi-vm-windows)

---

## How to use

Each template folder contains:
- `main.bicep` – the infrastructure definition
- `parameters.example.json` – example parameters (no secrets)
- `README.md` – usage instructions

To deploy:
1. Copy the example parameters file
2. Fill in required values (e.g. passwords)
3. Run `what-if`
4. Deploy

---

## Security notice

- **Secrets are never committed** to this repository
- Example parameter files contain placeholders only
- Always store real secrets in:
  - Azure Key Vault, or
  - CI/CD secrets (GitHub Actions / Azure Pipelines)

---

## About

Maintained by **ClaudOne**.  
Azure & cloud infrastructure work.

Feel free to fork, use, or adapt the templates.

## Contributions

Issues and pull requests are welcome.

