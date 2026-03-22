#!/usr/bin/env bats
# ibmvm setup — interactive wizard and prerequisite provisioning.
load helpers

# Helper: run setup with newline-separated answers piped to stdin.
# Prepends "n" to answer the "Keep these settings?" prompt shown on re-runs (n = customize).
run_setup() {
  run bash -c "printf '%s\n' n $* | bash '$IBMVM' setup"
}

# ── wizard prompts ────────────────────────────────────────────────────────────

@test "setup: prompts for region with current target as default" {
  echo "us-east" > "$IBMVM_MOCK_DIR/region"
  mock_infra
  # Pick region 1 (us-south from list); us-east should appear as the default label
  run_setup "1" "1" "ibmvm-vpc" "1" "1" "bx2-2x8" "root" "1"
  [ "$status" -eq 0 ]
  [[ "$output" == *"us-east"* ]]
}

@test "setup: prompts for resource group" {
  mock_infra
  # Pick "2" = Create new, then enter "my-rg", vpc="my-vpc", key=1
  run_setup "1" "2" "my-rg" "my-vpc" "1" "bx2-2x8" "root" "1"
  [ "$status" -eq 0 ]
  grep -q 'RG_NAME="my-rg"' "$IBMVM_CONFIG"
}

@test "setup: prompts for VPC name" {
  mock_infra
  run_setup "1" "1" "my-vpc" "1" "bx2-2x8" "root" "1"
  [ "$status" -eq 0 ]
  grep -q 'VPC_NAME="my-vpc"' "$IBMVM_CONFIG"
}

@test "setup: derives subnet and key names from resource group name" {
  mock_infra
  run_setup "1" "1" "ibmvm-vpc" "1" "1" "bx2-2x8" "root" "1"
  [ "$status" -eq 0 ]
  grep -q 'SUBNET_NAME="ibmvm-subnet"' "$IBMVM_CONFIG"
  grep -q 'KEY_NAME="ibmvm-key"' "$IBMVM_CONFIG"
}

@test "setup: prompts for SSH key path" {
  mock_infra
  # Create id_ed25519 too; sorted order: id_ed25519(1), id_rsa(2). Pick "1" = ed25519.
  touch "$HOME/.ssh/id_ed25519" "$HOME/.ssh/id_ed25519.pub"
  run_setup "1" "1" "ibmvm-vpc" "1" "1" "bx2-2x8" "root" "1"
  [ "$status" -eq 0 ]
  grep -q "SSH_KEY_FILE=\"$HOME/.ssh/id_ed25519\"" "$IBMVM_CONFIG"
}

@test "setup: prompts for VM profile" {
  mock_infra
  run_setup "1" "1" "ibmvm-vpc" "1" "1" "cx2-4x8" "root" "1"
  [ "$status" -eq 0 ]
  grep -q 'PROFILE="cx2-4x8"' "$IBMVM_CONFIG"
}

@test "setup: prompts for SSH user" {
  mock_infra
  run_setup "1" "1" "ibmvm-vpc" "1" "1" "bx2-2x8" "ubuntu" "1"
  [ "$status" -eq 0 ]
  grep -q 'SSH_USER="ubuntu"' "$IBMVM_CONFIG"
}

@test "setup: fetches images and prompts for selection" {
  mock_infra
  run_setup "1" "1" "ibmvm-vpc" "1" "1" "bx2-2x8" "root" "1"
  [ "$status" -eq 0 ]
  assert_called "ibmcloud is images"   # images were fetched during setup
}

@test "setup: stores selected image ID (not pattern) in config" {
  mock_infra
  run_setup "1" "1" "ibmvm-vpc" "1" "1" "bx2-2x8" "root" "1"
  [ "$status" -eq 0 ]
  grep -q 'IMAGE="img-ubuntu-' "$IBMVM_CONFIG"  # an actual ID, not a pattern
}

@test "setup: accepts blank input and keeps existing defaults" {
  # Pre-load config with custom values
  write_config 'RG_NAME="saved-rg"
VPC_NAME="saved-vpc"
PROFILE="mx2-2x16"
SSH_USER="ec2-user"'
  mock_infra
  # Add saved-rg so it appears in the resource groups list (blank → picks default index)
  echo "saved-rg" > "$IBMVM_MOCK_DIR/rg_saved_rg"
  # "n" = customize, then 7 blanks: region, rg, vpc, key, profile, user, image (subnet auto — saved-vpc has none)
  run bash -c "printf 'n\n\n\n\n\n\n\n\n' | bash '$IBMVM' setup"
  [ "$status" -eq 0 ]
  grep -q 'RG_NAME="saved-rg"'  "$IBMVM_CONFIG"
  grep -q 'PROFILE="mx2-2x16"'  "$IBMVM_CONFIG"
  grep -q 'SSH_USER="ec2-user"' "$IBMVM_CONFIG"
}

@test "setup: saves SETUP_DONE_REGION to config" {
  mock_infra
  run_setup "1" "1" "ibmvm-vpc" "1" "1" "bx2-2x8" "root" "1"
  [ "$status" -eq 0 ]
  grep -q 'SETUP_DONE_REGION="us-south"' "$IBMVM_CONFIG"
}

# ── infrastructure provisioning ───────────────────────────────────────────────

@test "setup: creates missing resource group" {
  # No rg files → resource groups list empty → "1" = Create new → enter "ibmvm"
  run_setup "1" "1" "ibmvm" "ibmvm" "1" "bx2-2x8" "root" "1"
  assert_called "resource group-create ibmvm"
}

@test "setup: skips resource group if already exists" {
  echo "ibmvm" > "$IBMVM_MOCK_DIR/rg_ibmvm"
  run_setup "1" "1" "ibmvm-vpc" "1" "bx2-2x8" "root" "1"
  refute_called "resource group-create"
}

@test "setup: creates missing VPC" {
  echo "ibmvm" > "$IBMVM_MOCK_DIR/rg_ibmvm"
  run_setup "1" "1" "ibmvm-vpc" "1" "bx2-2x8" "root" "1"
  assert_called "vpc-create ibmvm-vpc"
}

@test "setup: creates missing subnet" {
  echo "ibmvm" > "$IBMVM_MOCK_DIR/rg_ibmvm"
  echo "ibmvm-vpc" > "$IBMVM_MOCK_DIR/vpc_ibmvm_vpc"
  run_setup "1" "1" "ibmvm-vpc" "1" "bx2-2x8" "root" "1"
  assert_called "subnet-create ibmvm-subnet"
}

@test "setup: uploads missing SSH key" {
  echo "ibmvm" > "$IBMVM_MOCK_DIR/rg_ibmvm"
  echo "ibmvm-vpc" > "$IBMVM_MOCK_DIR/vpc_ibmvm_vpc"
  touch "$IBMVM_MOCK_DIR/subnet_ibmvm_subnet"
  run_setup "1" "1" "ibmvm-vpc" "1" "bx2-2x8" "root" "1"
  assert_called "key-create ibmvm-key"
}

@test "setup: skips SSH key if already uploaded" {
  mock_infra
  echo "ibmvm-key" > "$IBMVM_MOCK_DIR/key_ibmvm_key"
  run_setup "1" "1" "ibmvm-vpc" "1" "1" "bx2-2x8" "root" "1"
  refute_called "key-create"
}

@test "setup: adds SSH rule when none exists" {
  mock_infra
  run_setup "1" "1" "ibmvm-vpc" "1" "1" "bx2-2x8" "root" "1"
  assert_called "security-group-rule-add"
}

@test "commands exit with helpful error when setup not done" {
  write_config 'SETUP_DONE_REGION=""'
  mock_instance myvm running
  ibmvm list
  [ "$status" -ne 0 ]
  [[ "$output" == *"ibmvm setup"* ]]
}

@test "setup: login failure exits non-zero with message" {
  mock_logged_out
  ibmvm setup
  [ "$status" -ne 0 ]
  [[ "$output" == *"Not logged in"* ]]
}

@test "setup: auto-login with IBMCLOUD_APIKEY when not logged in" {
  mock_logged_out
  mock_infra
  # No prior config → first-time flow → "y" accepts proposed defaults (no pickers)
  run bash -c "printf 'y\n' | IBMCLOUD_APIKEY=test-key bash '${IBMVM}' setup"
  assert_called "login --apikey test-key"
}

# ── new picker tests ───────────────────────────────────────────────────────────

@test "setup: lists available regions as numbered options" {
  mock_infra
  run_setup "1" "1" "ibmvm-vpc" "1" "1" "bx2-2x8" "root" "1"
  [ "$status" -eq 0 ]
  [[ "$output" == *"us-south"* ]]
}

@test "setup: stores selected region from list" {
  mock_infra
  run_setup "1" "1" "ibmvm-vpc" "1" "1" "bx2-2x8" "root" "1"
  [ "$status" -eq 0 ]
  grep -q 'REGION="us-south"' "$IBMVM_CONFIG"
}

@test "setup: lists existing resource groups as numbered options" {
  mock_infra
  run_setup "1" "1" "ibmvm-vpc" "1" "1" "bx2-2x8" "root" "1"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ibmvm"* ]]
}

@test "setup: supports creating a new resource group by name" {
  mock_infra
  run_setup "1" "2" "my-rg" "ibmvm-vpc" "1" "1" "bx2-2x8" "root" "1"
  [ "$status" -eq 0 ]
  grep -q 'RG_NAME="my-rg"' "$IBMVM_CONFIG"
}

@test "setup: lists local SSH keys with IBM Cloud registration status" {
  mock_infra
  echo "SHA256:mockfp123" > "$IBMVM_MOCK_DIR/key_ibmvm_key"
  run_setup "1" "1" "ibmvm-vpc" "1" "1" "bx2-2x8" "root" "1"
  [ "$status" -eq 0 ]
  [[ "$output" == *"id_rsa"* ]]
}

@test "setup: stores path of selected SSH key" {
  mock_infra
  run_setup "1" "1" "ibmvm-vpc" "1" "1" "bx2-2x8" "root" "1"
  [ "$status" -eq 0 ]
  grep -q "SSH_KEY_FILE=\"${HOME}/.ssh/id_rsa\"" "$IBMVM_CONFIG"
}

@test "setup: shows checkmark for keys already registered in IBM Cloud" {
  mock_infra
  echo "SHA256:mockfp123" > "$IBMVM_MOCK_DIR/key_ibmvm_key"
  run_setup "1" "1" "ibmvm-vpc" "1" "1" "bx2-2x8" "root" "1"
  [ "$status" -eq 0 ]
  [[ "$output" == *"in IBM Cloud"* ]]
}

@test "setup: warns when profile is not found in IBM Cloud" {
  mock_infra
  # Extra "y" answers the "Continue anyway?" confirmation
  run_setup "1" "1" "ibmvm-vpc" "1" "1" "zz9-99x99" "y" "root" "1"
  [ "$status" -eq 0 ]
  [[ "$output" == *"not found in IBM Cloud"* ]]
}

@test "setup: aborts when unknown profile and user declines" {
  mock_infra
  run_setup "1" "1" "ibmvm-vpc" "1" "1" "zz9-99x99" "n"
  [ "$status" -ne 0 ]
}

@test "setup: no warning when profile is valid" {
  mock_infra
  run_setup "1" "1" "ibmvm-vpc" "1" "1" "cx2-4x8" "root" "1"
  [ "$status" -eq 0 ]
  [[ "$output" != *"not found in IBM Cloud"* ]]
}

@test "setup: saves config to per-account config file" {
  mock_infra
  run_setup "1" "1" "ibmvm-vpc" "1" "1" "bx2-2x8" "root" "1"
  [ "$status" -eq 0 ]
  [[ -f "$IBMVM_CONFIG" ]]
  ! [[ -f "$HOME/.ibmvm/config" ]]
}

@test "setup: lists existing subnets for chosen VPC" {
  mock_infra
  run_setup "1" "1" "ibmvm-vpc" "1" "1" "bx2-2x8" "root" "1"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ibmvm-subnet"* ]]
}

@test "setup: stores selected subnet name in config" {
  mock_infra
  run_setup "1" "1" "ibmvm-vpc" "1" "1" "bx2-2x8" "root" "1"
  [ "$status" -eq 0 ]
  grep -q 'SUBNET_NAME="ibmvm-subnet"' "$IBMVM_CONFIG"
}

@test "setup: auto-creates subnet name when VPC has none" {
  mock_infra
  run_setup "1" "1" "myvpc" "1" "bx2-2x8" "root" "1"
  [ "$status" -eq 0 ]
  grep -q 'SUBNET_NAME="myvpc-subnet"' "$IBMVM_CONFIG"
}

@test "setup: shows proposed config for first-time users" {
  write_config 'SETUP_DONE_REGION=""'
  mock_infra
  run bash -c "printf 'y\n' | bash '$IBMVM' setup"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Proposed"* ]]
}

@test "setup: first-time accepts defaults without running pickers" {
  write_config 'SETUP_DONE_REGION=""'
  mock_infra
  run bash -c "printf 'y\n' | bash '$IBMVM' setup"
  [ "$status" -eq 0 ]
  refute_called "regions"
}

@test "setup: first-time matches local key already registered in IBM Cloud" {
  write_config 'SETUP_DONE_REGION=""'
  mock_infra
  # Mark id_rsa fingerprint as registered in IBM Cloud
  echo "ibmvpc-key" > "$IBMVM_MOCK_DIR/key_ibmvpc_key"
  run bash -c "printf 'y\n' | bash '$IBMVM' setup"
  [ "$status" -eq 0 ]
  grep -q "SSH_KEY_FILE=\"${HOME}/.ssh/id_rsa\"" "$IBMVM_CONFIG"
}

@test "setup: shows current config summary on re-run" {
  mock_infra
  run bash -c "printf 'y\n' | bash '$IBMVM' setup"
  [ "$status" -eq 0 ]
  [[ "$output" == *"us-south"* ]]
  [[ "$output" == *"ibmvm"* ]]
}

@test "setup: skips pickers when user accepts current config" {
  mock_infra
  run bash -c "printf 'y\n' | bash '$IBMVM' setup"
  [ "$status" -eq 0 ]
  refute_called "regions"
}
