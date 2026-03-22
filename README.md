# ibmvm

A simple CLI for managing IBM Cloud VPC virtual machines.

## Prerequisites

- [IBM Cloud CLI](https://cloud.ibm.com/docs/cli) with the VPC plugin (`ibmcloud plugin install vpc-infrastructure`)
- [`jq`](https://jqlang.github.io/jq/)
- An IBM Cloud account

## Setup

Run once to configure your region, resource group, VPC, subnet, and SSH key:

```
./ibmvm setup
```

## Usage

```
ibmvm start   <name>    Start a VM (creates it if it doesn't exist)
ibmvm ssh     <name>    SSH in (starts it first if stopped)
ibmvm stop    <name>    Stop a running VM
ibmvm rm      <name>    Remove a VM and its floating IP
ibmvm rm      --all     Remove all ibmvm-* VMs (optionally tears down infra)
ibmvm list              List all VMs
ibmvm status  <name>    Show VM details
ibmvm create  <name>    Explicitly create a VM
```

VM names are automatically prefixed with `ibmvm-` — so `ibmvm start myvm` creates `ibmvm-myvm`.

## Options

```
--profile <name>    VM profile for create (default set during setup, e.g. bx2-2x8)
--image   <id>      Image ID for create (overrides the image chosen during setup)
```

## Examples

```sh
ibmvm setup                              # first-time setup
ibmvm ssh myvm                           # SSH in, creating the VM if needed
ibmvm ssh ubuntu@myvm                    # SSH as a specific user
ibmvm ssh myvm -- -L 8080:localhost:8080 # SSH with port forwarding
ibmvm create myvm --profile cx2-8x16    # create with a specific profile
ibmvm rm --all                           # remove all VMs
```

## Config

Settings are stored per IBM Cloud account in `~/.ibmvm/config.<account-id>`, managed by `ibmvm setup`.
