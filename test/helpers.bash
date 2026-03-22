# Shared bats test helpers — loaded via `load helpers` in each .bats file.

IBMVM="${BATS_TEST_DIRNAME}/../ibmvm"
MOCKS_DIR="${BATS_TEST_DIRNAME}/mocks"
MOCK_ACCOUNT_ID="mock-account-123"

setup() {
  # Each test gets a clean temp dir for mock state AND a fake HOME.
  export IBMVM_MOCK_DIR="${BATS_TEST_TMPDIR}/mock"
  mkdir -p "$IBMVM_MOCK_DIR"

  # Fake HOME so ~/.ibmvm config and ~/.ssh don't bleed in from the real system.
  export HOME="${BATS_TEST_TMPDIR}/home"
  mkdir -p "$HOME/.ibmvm" "$HOME/.ssh" "$HOME/.ibmcloud"
  export IBMVM_CONFIG="${HOME}/.ibmvm/config.${MOCK_ACCOUNT_ID}"

  # Fake SSH key pair
  touch "$HOME/.ssh/id_rsa" "$HOME/.ssh/id_rsa.pub"
  echo "ssh-rsa AAAA mock-key" > "$HOME/.ssh/id_rsa.pub"

  # Mock PATH: test mocks take priority over real ibmcloud / ssh.
  export PATH="${MOCKS_DIR}:${PATH}"

  # Default targeted region
  echo "us-south" > "$IBMVM_MOCK_DIR/region"

  # Mark prerequisites as already done (avoid setup running in every test).
  write_config "SETUP_DONE_REGION=\"us-south\""

  # Write a fake valid IAM token so check_login passes without a network call.
  mock_logged_in

  # Make IBMVM_MOCK_VPC available to the security-groups mock
  export IBMVM_MOCK_VPC="ibmvm-vpc"
}

teardown() {
  true  # bats cleans up BATS_TEST_TMPDIR automatically
}

# ── helpers ───────────────────────────────────────────────────────────────────

# Write ~/.ibmvm/config with default + extra content.
write_config() {
  cat > "$IBMVM_CONFIG" <<EOF
REGION="us-south"
PROFILE="bx2-2x8"
IMAGE="img-ubuntu-001"
SSH_USER="ubuntu"
SSH_KEY_FILE="${HOME}/.ssh/id_rsa"
ZONE="us-south-1"
SETUP_DONE_REGION="us-south"
RG_NAME="ibmvm"
VPC_NAME="ibmvm-vpc"
SUBNET_NAME="ibmvm-subnet"
KEY_NAME="ibmvm-key"
${1:-}
EOF
}

# Shorthand: run ibmvm with the given args.
ibmvm() { run bash "$IBMVM" "$@"; }

# Create a mock instance in a given state.
mock_instance() {
  local name="$1" status="${2:-running}"
  echo "$status" > "$IBMVM_MOCK_DIR/instance_$(slug "$name")_status"
  echo "$name"   > "$IBMVM_MOCK_DIR/instance_$(slug "$name")_name"
}

# Assign a floating IP to a mock instance.
mock_fip() {
  local name="$1" ip="${2:-1.2.3.4}"
  echo "$ip" > "$IBMVM_MOCK_DIR/instance_$(slug "$name")_fip"
}

# Mark infrastructure as existing in the mock.
mock_infra() {
  echo "ibmvm"                      > "$IBMVM_MOCK_DIR/rg_ibmvm"
  echo "ibmvm-vpc"                  > "$IBMVM_MOCK_DIR/vpc_ibmvm_vpc"
  printf 'ibmvm-subnet ibmvm-vpc'   > "$IBMVM_MOCK_DIR/subnet_ibmvm_subnet"
  echo "ibmvm-key"                  > "$IBMVM_MOCK_DIR/key_ibmvm_key"
}

# Check that calls.log contains a line matching the pattern.
assert_called() {
  grep -q "$1" "$IBMVM_MOCK_DIR/calls.log" \
    || { echo "Expected call matching '$1' not found in:"; cat "$IBMVM_MOCK_DIR/calls.log"; return 1; }
}

# Check that calls.log does NOT contain a line matching the pattern.
refute_called() {
  if grep -q "$1" "$IBMVM_MOCK_DIR/calls.log" 2>/dev/null; then
    echo "Unexpected call matching '$1' found in:"; cat "$IBMVM_MOCK_DIR/calls.log"; return 1
  fi
}

slug() { echo "$1" | tr '[:upper:]-' '[:lower:]_'; }

# Write a fake valid IAM token to ~/.ibmcloud/config.json (no network needed).
mock_logged_in() {
  local exp=$(( $(date +%s) + 3600 ))
  local b64payload
  b64payload=$(printf '{"exp":%d,"account":{"bss":"mock-account-123"}}' "$exp" | base64 | tr '+/' '-_' | tr -d '=\n')
  mkdir -p "$HOME/.ibmcloud"
  printf '{"IAMToken":"Bearer eyJhbGciOiJIUzI1NiJ9.%s.fakesig"}\n' "$b64payload" \
    > "$HOME/.ibmcloud/config.json"
}

# Remove the local token and mark the mock as logged out.
mock_logged_out() {
  rm -f "$HOME/.ibmcloud/config.json"
  touch "$IBMVM_MOCK_DIR/login_fail"
}
