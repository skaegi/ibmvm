#!/usr/bin/env bats
# ibmvm info — configured infrastructure and create defaults.
load helpers

@test "info: shows configured infrastructure and defaults" {
  ibmvm info
  [ "$status" -eq 0 ]
  [[ "$output" == *"Config file:"* ]]
  [[ "$output" == *"Region / zone:"* ]]
  [[ "$output" == *"ibmvm-vpc"* ]]
  [[ "$output" == *"ibmvm-access"* ]]
  [[ "$output" == *"Profile:"* ]]
  [[ "$output" == *"Image:"* ]]
  [[ "$output" == *"ibm-ubuntu-24-04-1-minimal-amd64-1"* ]]
  [[ "$output" == *"Image ID:"* ]]
}

@test "info: rejects arguments" {
  ibmvm info unexpected
  [ "$status" -ne 0 ]
  [[ "$output" == *"takes no arguments"* ]]
}
