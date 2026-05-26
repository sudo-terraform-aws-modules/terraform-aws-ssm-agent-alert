# Deployment Guide — SSM Ping Alert Module

This is the single reference for deploying this module into any customer account.

---

## How it detects SSM agent offline

Every 5 minutes, EventBridge triggers the Lambda function. Lambda calls
`ssm:DescribeInstanceInformation` and filters for instances where
`PingStatus = ConnectionLost`. For each one, it checks the EC2 state:

- Instance is **stopped or terminated** → intentional shutdown, no alert
- Instance launched **less than 5 minutes ago** → still booting, no alert
- Instance is **running** + SSM offline → genuine problem, **alert sent**

This approach detects real-time SSM agent connectivity loss, unlike the AWS Config
`EC2_INSTANCE_MANAGED_BY_SSM` rule which only evaluates on EC2 configuration changes.

---

## Prerequisites — check before every deployment

### AWS Config is NOT required

This module no longer uses AWS Config. No recorder check needed.

### Confirm subscription after apply

After `terraform apply`, AWS sends a "Confirm subscription" email to the Sudo alert
address. Someone must click the confirmation link before alerts are delivered.

---

## How to deploy for a new customer

### Step 1 — Create a caller directory for the customer

```
customers/
└── acme/
    ├── main.tf
    ├── provider.tf
    └── terraform.tfvars
```

**`main.tf`**
```hcl
module "ssm_ping_alert" {
  source = "git::https://code.sudoconsultants.com/sudoinclabs/terraform/terraform-ssm-agent-ping-alert.git"

  project_name    = var.project_name
  alert_email = var.alert_email
  tags             = var.tags
}

variable "project_name" {}
variable "alert_email" { sensitive = true }
variable "tags" { default = {} }
```

**`provider.tf`**
```hcl
provider "aws" {
  region = "us-east-1"
}
```

**`terraform.tfvars`**
```hcl
project_name = "acme"

tags = {
  Environment = "production"
  ManagedBy   = "terraform"
  Project     = "acme"
}
```

---

### Step 2 — Export the Sudo alert email

```bash
export TF_VAR_alert_email="support@sudoconsultants.com"
```

Never put this in any file committed to git.

---

### Step 3 — Confirm the right AWS account

```bash
aws sts get-caller-identity
```

Check the account ID matches the customer account before proceeding.

---

### Step 4 — Run Terraform

```bash
terraform init
terraform plan
terraform apply
```

---

### Step 5 — Confirm the SNS subscription

Check the inbox for the Sudo alert email and click the AWS confirmation link.

---

## Variables reference

### `project_name`
| | |
|---|---|
| Required | YES |
| Type | string |
| Allowed | Lowercase letters, numbers, hyphens only |

Prefix for every resource name. Example with `project_name = "acme"`:
```
acme-ssm-ping-alert-topic
acme-ssm-ping-alert-validator
acme-ssm-ping-alert-lambda-role
acme-ssm-ping-alert-ping-check  (EventBridge rule)
```

---

### `alert_email`
| | |
|---|---|
| Required | YES |
| Type | string (sensitive) |
| How to pass | `export TF_VAR_alert_email="support@sudoconsultants.com"` |

Never stored in any file. Terraform will not print it in plan or apply output.

---

### `schedule_expression`
| | |
|---|---|
| Required | NO |
| Type | string |
| Default | `"rate(5 minutes)"` |

Controls how often Lambda polls SSM ping status. Uses AWS EventBridge rate or cron syntax.

| Value | Behaviour |
|-------|-----------|
| `"rate(5 minutes)"` (default) | Checks every 5 minutes |
| `"rate(10 minutes)"` | Checks every 10 minutes |
| `"rate(1 hour)"` | Checks every hour |

---

### `initialization_grace_period_minutes`
| | |
|---|---|
| Required | NO |
| Type | number |
| Default | `5` |

Skips alert if instance launched less than N minutes ago. Prevents false alerts during boot.

| Value | When to use |
|-------|-------------|
| `5` (default) | Amazon Linux, Ubuntu |
| `10` or `15` | Windows or heavy user-data instances |
| `0` | Disables grace period |

---

### `lambda_timeout_seconds`
| | |
|---|---|
| Required | NO |
| Default | `15` |
| Range | 3 – 900 |

Lambda iterates over all ConnectionLost instances. If you have a large number of
instances increase this (e.g. `60`).

---

### `lambda_memory_mb`
| | |
|---|---|
| Required | NO |
| Default | `128` |
| Range | 128 – 10240 |

128 MB is sufficient for most accounts. Increase to `256` if Lambda duration is high.

---

### `tags`
| | |
|---|---|
| Required | NO |
| Default | `{}` |

The module always adds `Module = "ssm-ping-alert"` and `Project = <project_name>` automatically.

---

## What gets created

| Resource | Name pattern |
|----------|-------------|
| SNS Topic | `<customer>-ssm-ping-alert-topic` |
| SNS Subscription | Sudo alert email |
| IAM Role | `<customer>-ssm-ping-alert-lambda-role` |
| IAM Policy | `<customer>-ssm-ping-alert-lambda-policy` |
| Lambda Function | `<customer>-ssm-ping-alert-validator` |
| EventBridge Rule | `<customer>-ssm-ping-alert-ping-check` |

## What is NOT created

- AWS Config recorder or rules
- Additional SNS email subscriptions (add customer emails manually via SNS console)
