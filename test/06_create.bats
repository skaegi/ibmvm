#!/usr/bin/env bats
# ibmvm create — provisioning behaviour.
load helpers

@test "create: provisions a new instance and assigns floating IP" {
  mock_infra
  ibmvm create myvm
  [ "$status" -eq 0 ]
  assert_called "instance-create ibmvm-myvm"
  assert_called "floating-ip-reserve ibmvm-myvm-fip"
  [[ "$output" == *"IP:"* ]]
}

@test "create: uses default profile bx2-2x8" {
  mock_infra
  ibmvm create myvm
  [ "$status" -eq 0 ]
  assert_called "bx2-2x8"
}

@test "create: respects --profile flag" {
  mock_infra
  ibmvm create myvm --profile cx2-8x16
  [ "$status" -eq 0 ]
  assert_called "cx2-8x16"
}

@test "create: uses image ID stored in config (no lookup at create time)" {
  mock_infra
  ibmvm create myvm
  [ "$status" -eq 0 ]
  assert_called "img-ubuntu-001"   # ID stored by setup
  refute_called "ibmcloud is images"
}

@test "create: --image overrides config image" {
  mock_infra
  ibmvm create myvm --image r006-abc123
  [ "$status" -eq 0 ]
  assert_called "r006-abc123"
  refute_called "ibmcloud is images"
}

@test "create: fails if instance already exists" {
  mock_instance ibmvm-myvm running
  ibmvm create myvm
  [ "$status" -ne 0 ]
  [[ "$output" == *"already exists"* ]]
}

@test "create: requires a name argument" {
  ibmvm create
  [ "$status" -ne 0 ]
}
