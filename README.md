# cbci

Ansible code used to deploy openstack for CI testing, uses devstack and Hyper-V 2016

## Getting Started

These instructions will get you a copy of the project up and running on your local machine for development and testing purposes.

### Prerequisites

You will need 2 machines if live migration is not required.

For live migration two or more compute nodes and active directory are required.

For this example i will be using 4 VMs in VMware Workstation

* ubuntu 16.04 devstack - 1 NAT interface and one VMnet1 (host only)
* Hyper-V 2016 compute - 1 NAT interface and one VMnet1 (host only)
* Hyper-V 2016 compute - 1 NAT interface and one VMnet1 (host only)
* Server 2016 active directory - 1 NAT interface
* management network 192.168.171.0/24
* data network 192.168.112.0/24 VMnet1 (host only)


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

ansible -i inventory ad -m win_ping
192.168.171.139 | SUCCESS => {
    "changed": false, 
    "ping": "pong"
}

```

7. (Optional) Create snapshots for all VMs to be able to revert and run the build again

## Running ansible examples
```
ansible-playbook -i inventory build-devstack.yaml
ansible-playbook -i inventory build-hv2016-compute.yaml
ansible-playbook -i inventory build-ad.yaml
```

or

Using the parallel_task_runner.py (takes care of killing all other unfinished tasks if one fails)
```
python3 parallel_task_runner.py --tasks '{"Build devstack": {"cmd": "ansible-playbook -i inventory build-devstack.yaml", "log": "dvsm.log"}, "Build compute": {"cmd": "ansible-playbook -i inventory build-hv2016-compute.yaml", "log": "hv.log"}, "Build ad": {"cmd": "ansible-playbook -i inventory build-ad.yaml", "log": "ad.log"}}'
```

## Running the tests
```
ansible-playbook -i inventory post-stack.yaml
```
