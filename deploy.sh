#!/bin/bash

# Configuration
STACK_NAME="my-3tier-nested-stack"
TEMPLATE_FILE="ec2-stack.yaml"
REGION="us-east-1" # Change as needed

# Check for AWS CLI
if ! command -v aws &> /dev/null; then
    echo "Error: aws-cli is not installed. Please install it first."
    exit 1
fi

# Ask for KeyName if not provided as an argument
KEY_NAME=$1
if [ -z "$KEY_NAME" ]; then
    echo "Please provide the name of an existing EC2 KeyPair."
    echo "Usage: ./deploy.sh <YourKeyPairName>"
    exit 1
fi

echo "Deploying Nested CloudFormation stack: $STACK_NAME..."

# 1. Determine S3 bucket for packaging nested stacks
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
if [ $? -ne 0 ]; then
    echo "Error: Failed to get AWS Account ID. Please ensure your AWS CLI is configured."
    exit 1
fi

BUCKET_NAME="cf-packages-${ACCOUNT_ID}-${REGION}"

# 2. Check if bucket exists, create if it doesn't
echo "Checking S3 bucket for packaging: $BUCKET_NAME"
if ! aws s3api head-bucket --bucket "$BUCKET_NAME" 2>/dev/null; then
    echo "Creating S3 bucket $BUCKET_NAME..."
    if [ "$REGION" == "us-east-1" ]; then
        aws s3 mb "s3://$BUCKET_NAME" --region "$REGION"
    else
        aws s3api create-bucket --bucket "$BUCKET_NAME" --region "$REGION" --create-bucket-configuration LocationConstraint="$REGION"
    fi
else
    echo "S3 bucket $BUCKET_NAME exists."
fi

# 3. Package the stack (uploads nested templates to S3 and generates packaged-template.yaml)
echo "Packaging CloudFormation templates..."
aws cloudformation package \
    --template-file "$TEMPLATE_FILE" \
    --s3-bucket "$BUCKET_NAME" \
    --output-template-file packaged-template.yaml

if [ $? -ne 0 ]; then
    echo "Packaging failed."
    exit 1
fi

# 4. Deploy the packaged stack
echo "Deploying packaged template..."
aws cloudformation deploy \
    --stack-name "$STACK_NAME" \
    --template-file packaged-template.yaml \
    --region "$REGION" \
    --parameter-overrides KeyName="$KEY_NAME" \
    --capabilities CAPABILITY_IAM CAPABILITY_AUTO_EXPAND

if [ $? -eq 0 ]; then
    echo "Stack deployment started/updated successfully."
    echo "Fetching stack outputs..."
    aws cloudformation describe-stacks \
        --stack-name "$STACK_NAME" \
        --region "$REGION" \
        --query 'Stacks[0].Outputs' \
        --output table
else
    echo "Stack deployment failed."
    exit 1
fi
