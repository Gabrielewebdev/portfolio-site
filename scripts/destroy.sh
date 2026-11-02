#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

export AWS_PROFILE="${AWS_PROFILE:-portfolio}"
export AWS_REGION="${AWS_REGION:-us-east-1}"
export AWS_PAGER=""
STACK_NAME="portfolio-site"

stack_output() {
  local value
  value=$(aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --query "Stacks[0].Outputs[?OutputKey=='$1'].OutputValue | [0]" \
    --output text)
  if [[ -z "$value" || "$value" == "None" ]]; then
    echo "Missing stack output: $1" >&2
    return 1
  fi
  printf '%s' "$value"
}

bucket=$(stack_output BucketName)
website=$(stack_output WebsiteUrl)

aws sts get-caller-identity
printf '\nThis will take %s offline and delete bucket contents: %s\n' "$website" "$bucket"
read -r -p 'Type portfolio-site to confirm deletion: ' confirmation
if [[ "$confirmation" != "$STACK_NAME" ]]; then
  echo "Cancelled."
  exit 1
fi

aws s3 rm "s3://$bucket" --recursive
aws cloudformation delete-stack --stack-name "$STACK_NAME"
aws cloudformation wait stack-delete-complete --stack-name "$STACK_NAME"

echo "Stack deleted. Domain, hosted zone and external IAM role/provider remain."
