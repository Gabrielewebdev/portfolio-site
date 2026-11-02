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

test -s site/index.html
aws sts get-caller-identity

aws cloudformation deploy \
  --template-file template.yaml \
  --stack-name "$STACK_NAME" \
  --capabilities CAPABILITY_NAMED_IAM \
  --no-fail-on-empty-changeset

bucket=$(stack_output BucketName)
distribution=$(stack_output DistributionId)
website=$(stack_output WebsiteUrl)

aws s3 sync ./site "s3://$bucket" --delete
aws cloudfront create-invalidation \
  --distribution-id "$distribution" \
  --paths "/*"

printf '\nWebsite published: %s\nCache invalidation has been requested.\n' "$website"
