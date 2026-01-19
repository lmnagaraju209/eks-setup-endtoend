# Switching AWS Accounts - Terraform State Management

This guide explains how to switch AWS accounts and automatically create new state files in the new account.

## How It Works

The Terraform configuration now supports **automatic account-specific state files**. When you switch AWS accounts, Terraform will:

1. **Automatically detect the new AWS account ID**
2. **Create a new S3 bucket** with account ID in the name: `<project-name>-<account-id>-statefile`
3. **Create a new DynamoDB table** with account ID in the name: `<table-name>-<account-id>`
4. **Store state separately** for each AWS account

This allows you to:
- ✅ Use the same Terraform code across multiple AWS accounts
- ✅ Keep state files isolated per account
- ✅ Avoid conflicts when switching accounts
- ✅ Clean up old state files when no longer needed

## Configuration

The feature is enabled by default via the `include_account_id_in_bucket_name` variable:

```hcl
# In terraform.tfvars
include_account_id_in_bucket_name = true  # Default: true
```

### When Enabled (Default):
- **S3 Bucket Name**: `demoeks-123456789012-statefile`
- **DynamoDB Table**: `terraform-state-lock-123456789012`
- Format: `<base-name>-<account-id>-statefile`

### When Disabled:
- **S3 Bucket Name**: `demoeks-statefile`
- **DynamoDB Table**: `terraform-state-lock`
- Format: `<base-name>` (original behavior)

## Steps to Switch AWS Accounts

### 1. Configure New AWS Account Credentials

```bash
# Option A: AWS CLI Profiles
aws configure --profile new-account
# Enter Access Key ID, Secret Access Key, Region

# Option B: Environment Variables
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_DEFAULT_REGION="us-east-2"

# Option C: AWS SSO
aws sso login --profile new-account
```

### 2. Verify You're Using the New Account

```bash
# Check current AWS account
aws sts get-caller-identity --profile new-account

# Output should show the new account ID:
# {
#   "UserId": "...",
#   "Account": "987654321098",  # <-- New account ID
#   "Arn": "..."
# }
```

### 3. Update Terraform to Use New Profile (if using profiles)

```bash
# Option A: Environment Variable
export AWS_PROFILE=new-account

# Option B: In terraform.tfvars (if you have a way to set it)
# Note: Terraform provider uses AWS_PROFILE env var or default profile
```

### 4. Remove or Rename Old backend.tf

If you have a `backend.tf` file pointing to the old account:

```bash
# Option A: Rename it (keeps it as backup)
mv backend.tf backend.tf.old-account

# Option B: Remove it (if you don't need it)
rm backend.tf
```

### 5. Initialize Terraform for New Account

```bash
cd terraform

# Initialize without backend (will create new resources)
terraform init

# Or if you want to check first
terraform init -backend=false
```

### 6. Plan What Will Be Created

```bash
# This will show:
# - New S3 bucket: <project-name>-<new-account-id>-statefile
# - New DynamoDB table: <table-name>-<new-account-id>
# - All new infrastructure resources
terraform plan
```

### 7. Apply to New Account

```bash
# Creates new S3 bucket, DynamoDB table, and all infrastructure
terraform apply
```

### 8. Migrate State to S3 (Optional but Recommended)

After the first apply, migrate state to S3:

```bash
# 1. Copy backend example
cp backend.tf.example backend.tf

# 2. Get the actual bucket and table names
terraform output terraform_state_bucket_name
terraform output terraform_state_dynamodb_table

# 3. Edit backend.tf with actual values
# Update: bucket, dynamodb_table, region

# 4. Migrate state
terraform init -migrate-state

# 5. Verify state is in S3
terraform state list
```

## Example: Switching from Account A to Account B

### Account A (123456789012)
```bash
# Current state
terraform state list
# Shows resources in account 123456789012

# State stored in:
# - S3: demoeks-123456789012-statefile
# - DynamoDB: terraform-state-lock-123456789012
```

### Switch to Account B (987654321098)
```bash
# 1. Switch AWS credentials
export AWS_PROFILE=account-b

# 2. Verify new account
aws sts get-caller-identity
# Account: 987654321098

# 3. Remove old backend.tf
mv backend.tf backend.tf.account-a

# 4. Initialize for new account
terraform init

# 5. Apply (creates new bucket and table)
terraform apply
# Creates:
# - S3: demoeks-987654321098-statefile
# - DynamoDB: terraform-state-lock-987654321098
```

## State File Isolation

Each AWS account will have its own:

1. **S3 Bucket**: `<project>-<account-id>-statefile`
   - Contains Terraform state files
   - Isolated per account
   - Versioned and encrypted

2. **DynamoDB Table**: `<table-name>-<account-id>`
   - State locking table
   - Prevents concurrent modifications
   - Isolated per account

3. **State File**: `eks-setup/terraform.tfstate`
   - Same path in bucket, but different bucket per account
   - Tracks all infrastructure resources
   - Unique per account

## Important Notes

### ✅ Benefits
- **No Conflicts**: Each account has separate state
- **Easy Switching**: Just change AWS credentials
- **Safe**: Old state files are preserved
- **Clear**: Bucket/table names show account ID

### ⚠️ Considerations
- **No Shared State**: Resources in Account A won't be visible from Account B
- **Full Recreation**: Switching accounts means creating all infrastructure from scratch
- **Cost**: Each account will have its own S3 bucket and DynamoDB table
- **Cleanup**: Manually delete old buckets/tables if no longer needed

### 🔄 Returning to Previous Account
To switch back to a previous account:

```bash
# 1. Switch AWS credentials back
export AWS_PROFILE=account-a

# 2. Restore backend.tf for that account
cp backend.tf.account-a backend.tf

# 3. Re-initialize
terraform init

# 4. Your state is back
terraform state list
```

## Disabling Account-Specific Naming

If you want to use the same bucket/table names across accounts (not recommended):

```hcl
# In terraform.tfvars
include_account_id_in_bucket_name = false
```

**Warning**: This will cause conflicts if:
- Multiple accounts try to use the same bucket name
- Bucket already exists in another account

## Troubleshooting

### Error: Bucket Already Exists
```
Error: creating S3 bucket: BucketAlreadyExists: 
The requested bucket name is not available
```

**Solution**: The bucket name conflicts. Ensure `include_account_id_in_bucket_name = true` to include account ID.

### Error: Invalid Client Token
```
Error: InvalidClientTokenId: The security token included in the request is invalid
```

**Solution**: AWS credentials are incorrect or expired. Verify:
```bash
aws sts get-caller-identity
```

### Error: Access Denied
```
Error: AccessDenied: Access Denied
```

**Solution**: Current AWS credentials don't have permissions. Ensure:
- S3: Create bucket, PutObject, GetObject
- DynamoDB: CreateTable, PutItem, GetItem
- IAM: GetCallerIdentity

### State File Not Found After Switching
```
Error: Failed to get existing workspaces: NoSuchBucket
```

**Solution**: You're pointing to the old account's bucket. Either:
1. Switch AWS credentials back
2. Update `backend.tf` to point to new account's bucket
3. Or remove `backend.tf` and let Terraform create new resources

## Summary

With `include_account_id_in_bucket_name = true` (default):

- ✅ **Automatic account detection**: Terraform reads account ID from AWS credentials
- ✅ **Unique names per account**: Bucket and table names include account ID
- ✅ **No manual configuration**: Just switch AWS credentials and run terraform apply
- ✅ **Clean separation**: Each account has isolated state files

**To switch accounts**: Just change AWS credentials and run `terraform apply`. Terraform will automatically create account-specific state files!
