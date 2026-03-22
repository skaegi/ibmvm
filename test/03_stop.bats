#!/usr/bin/env bats
# ibmvm stop — state machine behaviour.
load helpers

@test "stop: already stopped reports status" {
  mock_instance ibmvm-myvm stopped
  ibmvm stop myvm
  [ "$status" -eq 0 ]
  [[ "$output" == *"already stopped"* ]]
  refute_called "instance-stop"
}

@test "stop: running instance calls instance-stop" {
  mock_instance ibmvm-myvm running
  ibmvm stop myvm
  [ "$status" -eq 0 ]
  assert_called "instance-stop ibmvm-myvm"
  [[ "$output" == *"stopped"* ]]
}

@test "stop: not-found exits non-zero" {
  ibmvm stop ghost
  [ "$status" -ne 0 ]
  [[ "$output" == *"not found"* ]]
}

@test "stop: requires a name argument" {
  ibmvm stop
  [ "$status" -ne 0 ]
}
