#!/bin/bash
# Create a Cognito user for testing

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

run_python() {
  if command -v py >/dev/null 2>&1; then
    py -3 "$@"
  elif command -v python3 >/dev/null 2>&1; then
    python3 "$@"
  elif command -v python >/dev/null 2>&1; then
    python "$@"
  else
    return 1
  fi
}

get_user_pool_id() {
  if command -v jq >/dev/null 2>&1; then
    echo "$1" | jq -r '.[] | select(.OutputKey == "UserPoolId" or .OutputKey == "AdminUserPoolId") | .OutputValue' | head -n 1
  else
    JSON_INPUT="$1" run_python - <<'PY'
import json
import os

for output in json.loads(os.environ["JSON_INPUT"]):
  if output.get("OutputKey") in {"UserPoolId", "AdminUserPoolId"}:
    value = output.get("OutputValue")
    if value:
      print(value)
      break
PY
  fi
}

STACK_NAME="${STACK_NAME:-}"
EMAIL=""
PASSWORD=""
GROUP=""

while [[ $# -gt 0 ]]; do
    case "$1" in
    --stack-name)
      STACK_NAME="$2"
      shift 2
      ;;
        --group)
            GROUP="$2"
            shift 2
            ;;
    -h|--help)
      echo -e "${BLUE}Usage:${NC} $0 <email> <password> --stack-name <CallCenterTraining-Web|CallCenterTraining-Connect> [--group admin|trainee]"
      echo ""
      echo "Examples:"
      echo "  $0 user@example.com Password123! --stack-name CallCenterTraining-Web"
      echo "  $0 admin@example.com Password123! --stack-name CallCenterTraining-Connect"
      echo "  STACK_NAME=CallCenterTraining-Web $0 user@example.com Password123! --group admin"
      echo ""
      exit 0
      ;;
        *)
      if [ -z "$EMAIL" ]; then
        EMAIL="$1"
      elif [ -z "$PASSWORD" ]; then
        PASSWORD="$1"
      else
        echo -e "${RED}Error:${NC} Unknown argument: $1"
        exit 1
      fi
      shift
            ;;
    esac
done

if [ -z "$EMAIL" ] || [ -z "$PASSWORD" ]; then
  echo -e "${RED}Usage:${NC} $0 <email> <password> --stack-name <CallCenterTraining-Web|CallCenterTraining-Connect> [--group admin|trainee]"
    echo ""
    echo "Example:"
  echo "  $0 test@example.com Password123! --stack-name CallCenterTraining-Web"
  echo "  $0 admin@example.com Password123! --stack-name CallCenterTraining-Connect --group admin"
    echo ""
    exit 1
fi

if [ -z "$STACK_NAME" ]; then
  echo -e "${RED}Error:${NC} Missing required --stack-name argument."
  echo "Use CallCenterTraining-Web for the browser app or CallCenterTraining-Connect for the Connect admin UI."
  exit 1
fi

echo -e "${BLUE}Creating Cognito user...${NC}"
echo "Target stack: $STACK_NAME"

# Get User Pool ID
STACK_OUTPUTS=$(aws cloudformation describe-stacks \
  --stack-name "$STACK_NAME" \
  --query 'Stacks[0].Outputs' \
  --output json)

USER_POOL_ID=$(get_user_pool_id "$STACK_OUTPUTS")

if [ -z "$USER_POOL_ID" ] || [ "$USER_POOL_ID" = "None" ] || [ "$USER_POOL_ID" = "N/A" ]; then
    echo -e "${RED}Error:${NC} Could not find a Cognito User Pool output from stack $STACK_NAME"
    exit 1
fi

echo "User Pool ID: $USER_POOL_ID"
echo "Email: $EMAIL"

# Check if user already exists
if aws cognito-idp admin-get-user \
  --user-pool-id "$USER_POOL_ID" \
  --username "$EMAIL" &> /dev/null; then

    echo -e "${BLUE}User already exists. Updating password...${NC}"

    aws cognito-idp admin-set-user-password \
      --user-pool-id "$USER_POOL_ID" \
      --username "$EMAIL" \
      --password "$PASSWORD" \
      --permanent

    echo -e "${GREEN}✓${NC} Password updated for $EMAIL"
else
    echo -e "${BLUE}Creating new user...${NC}"

    aws cognito-idp admin-create-user \
      --user-pool-id "$USER_POOL_ID" \
      --username "$EMAIL" \
      --temporary-password "$PASSWORD" \
      --message-action SUPPRESS

    # Set permanent password
    aws cognito-idp admin-set-user-password \
      --user-pool-id "$USER_POOL_ID" \
      --username "$EMAIL" \
      --password "$PASSWORD" \
      --permanent

    echo -e "${GREEN}✓${NC} User created: $EMAIL"
fi

if [ -n "$GROUP" ]; then
    echo -e "${BLUE}Adding user to group '${GROUP}'...${NC}"

    aws cognito-idp admin-add-user-to-group \
      --user-pool-id "$USER_POOL_ID" \
      --username "$EMAIL" \
      --group-name "$GROUP"

    echo -e "${GREEN}✓${NC} Added to group: $GROUP"
fi

echo ""
echo "Credentials:"
echo "  Email:    $EMAIL"
echo "  Password: $PASSWORD"
if [ -n "$GROUP" ]; then
    echo "  Group:    $GROUP"
fi
echo ""
echo -e "${GREEN}Done!${NC} You can now sign in to the application."
