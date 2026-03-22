#!/usr/bin/env bats
# ibmvm rm — confirmation flow, floating-IP cleanup, and --all teardown.
load helpers

@test "rm: removes instance immediately (no prompt)" {
  mock_instance ibmvm-myvm running
  mock_fip ibmvm-myvm 1.2.3.4
  ibmvm rm myvm
  [ "$status" -eq 0 ]
  assert_called "floating-ip-release"
  assert_called "instance-delete ibmvm-myvm"
}

@test "rm: releases floating IP before deleting instance" {
  mock_instance ibmvm-myvm running
  mock_fip ibmvm-myvm 9.9.9.9
  ibmvm rm myvm
  [ "$status" -eq 0 ]
  release_line=$(grep -n "floating-ip-release" "$IBMVM_MOCK_DIR/calls.log" | head -1 | cut -d: -f1)
  delete_line=$(grep -n "instance-delete" "$IBMVM_MOCK_DIR/calls.log" | head -1 | cut -d: -f1)
  [ "${release_line:-0}" -lt "${delete_line:-9999}" ]
}

@test "rm: not-found exits non-zero" {
  run bash -c "echo 'y' | bash '$IBMVM' rm ghost"
  [ "$status" -ne 0 ]
  [[ "$output" == *"not found"* ]]
}

@test "rm: requires a name argument" {
  ibmvm rm
  [ "$status" -ne 0 ]
}

# ── rm --all ──────────────────────────────────────────────────────────────────

@test "rm --all: removes all ibmvm-prefixed instances when confirmed" {
  mock_instance ibmvm-vm1 running
  mock_instance ibmvm-vm2 stopped
  mock_infra
  # First 'y' confirms instance removal; second 'n' declines infra teardown
  run bash -c "printf 'y\nn\n' | bash '$IBMVM' rm --all"
  [ "$status" -eq 0 ]
  assert_called "instance-delete ibmvm-vm1"
  assert_called "instance-delete ibmvm-vm2"
}

@test "rm --all: does not remove instances without ibmvm- prefix" {
  mock_instance ibmvm-vm1 running
  mock_instance other-vm running   # should not be touched
  mock_infra
  run bash -c "printf 'y\nn\n' | bash '$IBMVM' rm --all"
  [ "$status" -eq 0 ]
  assert_called "instance-delete ibmvm-vm1"
  refute_called "instance-delete other-vm"
}

@test "rm --all: aborts when user declines instance removal" {
  mock_instance ibmvm-vm1 running
  mock_infra
  run bash -c "printf 'n\n' | bash '$IBMVM' rm --all"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Aborted"* ]]
  refute_called "instance-delete"
}

@test "rm --all: reports no instances when resource group is empty" {
  mock_infra
  # No instances created → skip to infra teardown prompt; 'n' declines teardown
  run bash -c "printf 'n\n' | bash '$IBMVM' rm --all"
  [ "$status" -eq 0 ]
  [[ "$output" == *"No instances"* ]]
}

@test "rm --all: tears down infra when confirmed" {
  mock_infra
  # First 'y' skips instances (none), second 'y' confirms infra teardown
  run bash -c "printf 'y\n' | bash '$IBMVM' rm --all"
  [ "$status" -eq 0 ]
  assert_called "key-delete"
  assert_called "subnet-delete"
  assert_called "vpc-delete"
  assert_called "group-delete ibmvm"
}

@test "rm --all: skips infra teardown when declined" {
  mock_instance ibmvm-vm1 running
  mock_infra
  # 'y' confirms instance removal, 'n' declines infra teardown
  run bash -c "printf 'y\nn\n' | bash '$IBMVM' rm --all"
  [ "$status" -eq 0 ]
  refute_called "vpc-delete"
}
