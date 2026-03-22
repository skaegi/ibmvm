#!/usr/bin/env bats
# ibmvm ssh — connection and state-machine behaviour.
load helpers

@test "ssh: connects to running instance" {
  mock_instance ibmvm-myvm running
  mock_fip ibmvm-myvm 5.6.7.8
  ibmvm ssh myvm
  [ "$status" -eq 0 ]
  assert_called "ssh.*ubuntu@5.6.7.8"
}

@test "ssh: user@vm syntax overrides default user" {
  mock_instance ibmvm-myvm running
  mock_fip ibmvm-myvm 5.6.7.8
  ibmvm ssh ubuntu@myvm
  [ "$status" -eq 0 ]
  assert_called "ssh.*ubuntu@5.6.7.8"
}

@test "ssh: passes extra args after --" {
  mock_instance ibmvm-myvm running
  mock_fip ibmvm-myvm 5.6.7.8
  ibmvm ssh myvm -- -L 8080:localhost:8080
  [ "$status" -eq 0 ]
  assert_called "\-L 8080:localhost:8080"
}

@test "ssh: stopped instance prompts to start (y → starts then connects)" {
  mock_instance ibmvm-myvm stopped
  mock_fip ibmvm-myvm 5.6.7.8
  run bash -c "echo 'y' | bash '$IBMVM' ssh myvm"
  [ "$status" -eq 0 ]
  assert_called "instance-start ibmvm-myvm"
  assert_called "ssh.*ubuntu@5.6.7.8"
}

@test "ssh: stopped instance prompts to start (n → aborts)" {
  mock_instance ibmvm-myvm stopped
  run bash -c "echo 'n' | bash '$IBMVM' ssh myvm"
  [ "$status" -eq 0 ]
  refute_called "instance-start"
}

@test "ssh: not-found prompts to create (n → aborts)" {
  run bash -c "echo 'n' | bash '$IBMVM' ssh ghost"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Aborted"* ]]
  refute_called "instance-create"
}

@test "ssh: not-found prompts to create (y → creates then connects)" {
  mock_infra
  run bash -c "echo 'y' | bash '$IBMVM' ssh newvm"
  [ "$status" -eq 0 ]
  assert_called "instance-create ibmvm-newvm"
}

@test "ssh: missing floating IP exits non-zero" {
  mock_instance ibmvm-myvm running
  # no mock_fip → no floating IP
  ibmvm ssh myvm
  [ "$status" -ne 0 ]
  [[ "$output" == *"No floating IP"* ]]
}
