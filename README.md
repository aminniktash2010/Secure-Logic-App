# Secure-Logic-App
terraform project creating a function app in azure and a logic app with a workflow to Triger the function app each 10 minutes schedule, this solution is following best security practices
Security Best Practices Implemented:

Network Isolation

Functions and Logic Apps deployed in separate subnets

NSG rules restricting traffic between subnets

Function App only accepts HTTPS traffic

Identity Management

System-assigned managed identities for both services

Least privilege access through network security groups

Data Protection

Storage accounts with encryption enabled

FTPS disabled for secure file transfer

HTTPS enforced for all communications

State Management

Secure Azure backend for Terraform state

State file encryption through Azure Storage

Workflow Security

Private connection between Logic Apps and Functions

Secure parameters for connection configuration


This implementation creates a secure environment where:

Functions are triggered every 10 minutes via Logic Apps

All internal communication uses private network paths

Sensitive data is protected through managed identities

Infrastructure changes are tracked through versioned state files

To enhance security further:

Integrate Azure Key Vault for secret management

Enable Azure Monitor for both services

Implement private endpoints for Azure Services

Regular vulnerability scanning of Terraform code
