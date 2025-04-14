# AWS Infrastructure Automation with Terraform & Jenkins

## 📁 Project Overview

This project automates the provisioning and management of AWS infrastructure using Terraform, integrated with Jenkins CI/CD pipelines for continuous deployment. The infrastructure is version-controlled with GitHub and configured to store Terraform state files remotely in an S3 bucket with DynamoDB for state locking.

---

## 📌 Features

- Infrastructure-as-Code with Terraform
- Automated CI/CD Pipeline via Jenkins
- GitHub integration for SCM
- AWS S3 for backend state management
- DynamoDB for state locking
- Secure AWS credentials via Jenkins credentials plugin
- Detailed post-stage reporting for success/failure

---

## 🛠️ Technologies Used

| Technology | Role |
|------------|------|
| Terraform  | Infrastructure provisioning |
| AWS        | Cloud provider |
| Jenkins    | CI/CD automation |
| GitHub     | Source code version control |
| S3         | Remote state storage |
| DynamoDB   | Terraform state locking |
| AWS Credentials Plugin | Secure credential injection in Jenkins |

---

## 📂 Repository Structure

```
AWS-Infrastructure/
│
├── Jenkinsfile               # Jenkins pipeline definition
├── main.tf                   # Main Terraform configuration
├── variables.tf              # Input variable definitions
├── outputs.tf                # Output values
├── providers.tf              # AWS provider configuration
├── backend.tf                # Remote backend config (S3 + DynamoDB)
└── modules/                  # Optional: reusable Terraform modules
```

---

## ⚙️ Jenkins Pipeline (Jenkinsfile)

```groovy
pipeline {
  agent any

  environment {
    AWS_REGION = 'us-west-2'
  }

  stages {
    stage('Terraform Init') {
      steps {
        withAWS(region: "${env.AWS_REGION}", credentials: 'aws-credentials-id') {
          sh 'terraform init'
        }
      }
      post {
        success {
          echo 'Terraform Init completed successfully.'
        }
        failure {
          echo 'Terraform Init failed.'
        }
        always {
          echo 'Terraform Init stage finished.'
        }
      }
    }

    stage('Terraform Plan') {
      steps {
        withAWS(region: "${env.AWS_REGION}", credentials: 'aws-credentials-id') {
          sh 'terraform plan'
        }
      }
      post {
        success {
          echo 'Terraform Plan completed successfully.'
        }
        failure {
          echo 'Terraform Plan failed.'
        }
        always {
          echo 'Terraform Plan stage finished.'
        }
      }
    }

    stage('Terraform Apply') {
      steps {
        withAWS(region: "${env.AWS_REGION}", credentials: 'aws-credentials-id') {
          sh 'terraform apply -auto-approve'
        }
      }
      post {
        success {
          echo 'Terraform Apply completed successfully.'
        }
        failure {
          echo 'Terraform Apply failed.'
        }
        always {
          echo 'Terraform Apply stage finished.'
        }
      }
    }
  }
}
```

---

## ☁️ Terraform Backend Configuration (`backend.tf`)

```hcl
terraform {
  backend "s3" {
    bucket         = "your-terraform-state-bucket"
    key            = "infra/terraform.tfstate"
    region         = "us-west-2"
    dynamodb_table = "terraform-state-lock" # Deprecated warning seen, consider using use_lockfile instead
  }
}
```

> ✅ **Note:** You may see a deprecation warning for `dynamodb_table`. Use `use_lockfile` for future compatibility.

---

## 🔐 Jenkins Credentials Setup

1. Go to **Jenkins Dashboard > Manage Jenkins > Credentials > (Global) > Add Credentials**
2. Select **Kind:** *AWS Credentials*
3. Fill in:
   - **Access Key ID**
   - **Secret Access Key**
   - **ID:** `aws-credentials-id` (used in `withAWS`)
4. Save.

---

## 🔄 CI/CD Flow

1. Developer pushes changes to GitHub repository.
2. Jenkins automatically pulls the latest code via webhook or polling.
3. Jenkinsfile runs the following stages:
   - `Terraform Init`: Initializes Terraform environment and backend.
   - `Terraform Plan`: Shows planned infrastructure changes.
   - `Terraform Apply`: Applies the infrastructure changes (if previous stages succeed).
4. Each stage provides post-execution logs for monitoring.

---

## 🧪 Troubleshooting

| Issue | Cause | Fix |
|-------|-------|-----|
| `No valid credential sources found` | AWS credentials not injected | Ensure `withAWS` is used and credentials ID matches |
| `Deprecated Parameter dynamodb_table` | S3 backend config warning | Replace with `use_lockfile = true` |
| `Planning failed: failed to get shared config profile` | Missing or incorrect AWS provider config | Ensure `provider "aws"` is using env vars or injected credentials |

---

## 📘 References

- [Terraform Docs](https://developer.hashicorp.com/terraform/docs)
- [Jenkins Pipeline Syntax](https://www.jenkins.io/doc/book/pipeline/syntax/)
- [AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [AWS Credentials Plugin](https://plugins.jenkins.io/aws-credentials/)

---

## 📝 Contributing

Contributions are welcome! Please follow these guidelines:

1. Fork the repository.
2. Create a new branch for your feature or bug fix.
3. Make your changes and commit them.
4. Push your changes to your fork.
5. Submit a pull request.

---

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
