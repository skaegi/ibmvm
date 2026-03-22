#!/usr/bin/env bats
# Argument parsing and runtime flags.
load helpers

@test "no args prints usage" {
  ibmvm
  [ "$status" -eq 0 ]
  [[ "$output" == *"USAGE"* ]]
}

@test "no args prints usage even without a config file" {
  rm -f "$HOME/.ibmvm/config"
  ibmvm
  [ "$status" -eq 0 ]
  [[ "$output" == *"USAGE"* ]]
}

@test "help prints usage" {
  ibmvm help
  [ "$status" -eq 0 ]
  [[ "$output" == *"COMMANDS"* ]]
}

@test "--help prints usage" {
  ibmvm --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"COMMANDS"* ]]
}

@test "unknown command exits non-zero" {
  ibmvm flibbertigibbet
  [ "$status" -ne 0 ]
  [[ "$output" == *"Unknown command"* ]]
}

@test "unknown flag exits non-zero" {
  ibmvm --notaflag list
  [ "$status" -ne 0 ]
}

@test "--profile is passed to instance-create" {
  mock_infra
  ibmvm create myvm --profile cx2-8x16
  assert_called "instance-create"
  assert_called "cx2-8x16"
}

@test "--profile on non-create command is an error" {
  mock_instance ibmvm-myvm running
  mock_fip ibmvm-myvm 1.2.3.4
  ibmvm list --profile mx2-4x32
  [ "$status" -ne 0 ]
}

@test "user@vm syntax is parsed by ssh command" {
  mock_instance ibmvm-myvm running
  mock_fip ibmvm-myvm 5.6.7.8
  ibmvm ssh ubuntu@myvm
  [ "$status" -eq 0 ]
  assert_called "ssh.*ubuntu@5.6.7.8"
}
