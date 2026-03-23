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
ibmvm ssh     <name>    SSH in (starts if stopped, prompts to allow your IP if needed)
ibmvm stop    <name>    Stop a running VM
ibmvm rm      <name>    Remove a VM and its floating IP
ibmvm rm      --all     Remove all ibmvm-* VMs (optionally tears down infra)
ibmvm list              List all VMs
ibmvm status  <name>    Show VM details
ibmvm create  <name>    Explicitly create a VM
```

VM names are automatically prefixed with `ibmvm-` — so `ibmvm start myvm` creates `ibmvm-myvm`.

## Access control

SSH access is managed through a dedicated `ibmvm-access` security group. Only IPs you explicitly allow can reach your VMs on port 22.

```
ibmvm access list           Show currently allowed IPs and when they were added
ibmvm access allow          Allow your current public IP
ibmvm access allow 1.2.3.4  Allow a specific IP
ibmvm access deny           Remove your current public IP
ibmvm access deny --all     Lock down (remove all SSH access rules)
```

`ibmvm ssh` checks whether your current public IP is allowed and prompts to add it if not. Both IPv4 and IPv6 are supported. Use `ibmvm access deny --all` when you're done to close the door.

## Options

```
--profile <name>    VM profile for create (default set during setup, e.g. bx2-2x8)
--image   <name>    Image name or pattern for create, e.g. ubuntu-24 (overrides setup default)
```

## Examples

```sh
ibmvm setup                              # first-time setup
ibmvm ssh myvm                           # SSH in (auto-allows your IP, creates VM if needed)
ibmvm ssh ubuntu@myvm                    # SSH as a specific user
ibmvm ssh myvm -- -L 8080:localhost:8080 # SSH with port forwarding
ibmvm create myvm --profile cx2-8x16    # create with a specific profile
ibmvm access deny --all                  # lock down when done
ibmvm rm --all                           # remove all VMs
```

## Config

Settings are stored per IBM Cloud account in `~/.ibmvm/config.<account-id>`, managed by `ibmvm setup`.
