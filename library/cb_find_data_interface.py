try:
    import netaddr
    HAS_NETADDR = True
except ImportError:
    HAS_NETADDR = False
try:
    import netifaces
    HAS_NETIFACES = True
except ImportError:
    HAS_NETIFACES = False
 
from ansible.module_utils.basic import AnsibleModule
 
 
def check_interfaces(address):
    result = {
        'found': False,
        'name': '',
        'interfaces': {}
    }
 
    for interface in netifaces.interfaces():
        addresses = netifaces.ifaddresses(interface)
        result['interfaces'][interface] = addresses
 
        if result['name']:
            continue
 
        try:
            if netaddr.IPAddress(addresses[netifaces.AF_INET][0]['addr']) in netaddr.IPNetwork(address):
                    result['found'] = True
                    result['name'] = interface
        except KeyError:
            pass
 
    return result
 
 
def main():
    module = AnsibleModule(
        argument_spec=dict(
            subnet=dict(required=True)
        )
    )
 
    if not HAS_NETADDR:
        module.fail_json(msg='The netaddr python module is required')
    if not HAS_NETIFACES:
        module.fail_json(msg='The netifaces python module is required')
 
    subnet = module.params['subnet']
 
    result_interface = check_interfaces(subnet)
    if not result_interface['found']:
        module.fail_json(data=result_interface, msg='No interface in subnet %s' % subnet)
 
    module.exit_json(data=result_interface)
 
 
if __name__ == '__main__':
    main()
