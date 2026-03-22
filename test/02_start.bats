#!/usr/bin/env bats
# ibmvm start — state machine behaviour.
load helpers

@test "start: already running reports status" {
  mock_instance ibmvm-myvm running
  ibmvm start myvm
  [ "$status" -eq 0 ]
  [[ "$output" == *"already running"* ]]
  refute_called "instance-start"
}

@test "start: stopped instance calls instance-start" {
  mock_instance ibmvm-myvm stopped
  ibmvm start myvm
  [ "$status" -eq 0 ]
  assert_called "instance-start ibmvm-myvm"
  [[ "$output" == *"running"* ]]
}

@test "start: missing instance prompts to create (y → creates)" {
  mock_infra
  run bash -c "echo 'y' | bash '$IBMVM' start newvm"
  [ "$status" -eq 0 ]
  assert_called "instance-create ibmvm-newvm"
}

@test "start: missing instance prompts to create (n → aborts)" {
  run bash -c "echo 'n' | bash '$IBMVM' start newvm"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Aborted"* ]]
  refute_called "instance-create"
}

@test "start: requires a name argument" {
  ibmvm start
  [ "$status" -ne 0 ]
  [[ "$output" == *"Usage"* ]]
}
