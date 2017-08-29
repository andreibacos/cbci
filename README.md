# cbci

Ansible code used to deploy openstack for CI testing, uses devstack and Hyper-V 2016

## Getting Started

These instructions will get you a copy of the project up and running on your local machine for development and testing purposes.

### Prerequisites

You will need 2 or more machines each with 2 network interfaces in different subnets

One will be used for management and the other for data network, just make sure both interfaces have IPs set

For this example i will be using 2 VMs in VMware Workstation

* ubuntu 16.04 - 1 NAT interface and one VMnet1 (host only)
* Hyper-V 2016 - 1 NAT interface and one VMnet1 (host only)
* management network 192.168.171.0/24
* data network 192.168.112.0/24 (host only)


### Installing

1. Install ansible 2.3+ on your control machine
```
$ sudo apt-add-repository ppa:ansible/ansible
$ sudo apt-get update
$ sudo apt-get install ansible
```

2. Clone this repo

3. Change zuul-params.yaml
```
zuul_head_only: true means no change will be applied on top of zuul-branch
devstack_ip will be used to configure services on the compute node(s)
```

4. Change group variables in group_vars folder to your liking. (ie: ssh/winrm password)
For this example i will just make sure data_network(group_vars/all) is set to my VMnet1 subnet

5. Update inventory file with the correct IPs

6. Configure your machines to work with ansible. For windows just run [this script](https://github.com/ansible/ansible/blob/devel/examples/scripts/ConfigureRemotingForAnsible.ps1)
```
ansible -i inventory devstack -m ping
192.168.171.134 | SUCCESS => {
    "changed": false, 
    "ping": "pong"
}

ansible -i inventory windows -m win_ping
192.168.171.139 | SUCCESS => {
    "changed": false, 
    "ping": "pong"
}

```

## Running ansible
```
ansible-playbook -i inventory build-devstack.yaml
ansible-playbook -i inventory build-hv2016-compute.yaml
```

or

Using the parallel_task_runner.py
```
python3 parallel_task_runner.py --tasks '{"Build devstack": {"cmd": "ansible-playbook -i inventory build-devstack.yaml", "log": "dvsm.log"}, "Build compute": {"cmd": "ansible-playbook -i inventory build-hv2016-compute.yaml", "log": "hv.log"}}'
```
