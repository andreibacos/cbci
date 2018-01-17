from ansible.module_utils.basic import AnsibleModule
import os
from subprocess import Popen, PIPE

 
def main():
    module = AnsibleModule(
        argument_spec=dict(
            url=dict(type="str", required=True),
            ref=dict(type="list", required=True),
            path=dict(type="path", required=True)

        )
    )
  
    url = module.params['url']
    ref = module.params['ref']
    path = module.params['path']
    result = dict()

    if not os.path.isdir(path):
        module.fail_json(msg='Folder %s does not exist' % path)

    # make sure we have these set
    Popen("git config --global user.email cbci@cloudbasesolutions.com".split(), stdout=PIPE, stderr=PIPE).communicate()
    Popen("git config --global user.name CBCI".split(), stdout=PIPE, stderr=PIPE).communicate()

    for r in ref:
        result[r] = dict()
        fetch_cmd = "git -C %s fetch %s %s" % (path, url, r)
        result[r][fetch_cmd] = dict()
        try:
            process = Popen(fetch_cmd.split(), stdout=PIPE, stderr=PIPE)
            fetch_cmd_out, fetch_cmd_err = process.communicate()
            result[r][fetch_cmd]["stdout"] = fetch_cmd_out.splitlines()
            result[r][fetch_cmd]["stderr"] = fetch_cmd_err.splitlines()
        except Exception as e:
            module.fail_json(output=result, msg='Failed command %s: %s' % (fetch_cmd, str(e)))

        cherry_pick_cmd = "git -C %s cherry-pick FETCH_HEAD" % path
        result[r][cherry_pick_cmd] = dict()

        try:
            process = Popen(cherry_pick_cmd.split(), stdout=PIPE, stderr=PIPE)
            cherry_pick_cmd_out, cherry_pick_cmd_err = process.communicate()
            result[r][cherry_pick_cmd]["stdout"] = cherry_pick_cmd_out.splitlines()
            result[r][cherry_pick_cmd]["stderr"] = cherry_pick_cmd_err.splitlines()
        except Exception as e:
            result[r][cherry_pick_cmd] = str(e).splitlines()
            abort_cmd = "git -C %s cherry-pick --abort" % path
            result[r][abort_cmd] = dict()
            try:
                process = Popen(abort_cmd.split(), stdout=PIPE, stderr=PIPE)
                abort_cmd_out, abort_cmd_err = process.communicate()
                result[r][abort_cmd]["stdout"] = abort_cmd_out.splitlines()
                result[r][abort_cmd]["stderr"] = abort_cmd_err.splitlines()
            except Exception as e:
                result[r][abort_cmd] = str(e).splitlines()
 
    module.exit_json(output=result)
 
 
if __name__ == '__main__':
    main()
