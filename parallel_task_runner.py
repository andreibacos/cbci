import subprocess
from pprint import pprint, pformat
import sys
import time
import os
import signal
from optparse import OptionParser, OptionValueError
import json


loop_check_delay = 5
processes = {}

tasks_example = {
    "Build devstack":
        {"cmd": "ansible-playbook -i inventory build-devstack.yaml",
         "log": "dvsm.log"},
    "Build compute":
        {"cmd": "ansible-playbook -i inventory build-win2016-compute.yaml",
         "log": "hv.log"}
}


# capture SIGINT (ctrl+c) and SIGTERM and kill everything if necessary
def sigint(s, f):
    print("Received signal: %s" % s)
    for t, proc in list(processes.items()):
        print("Killing task: %s" % t)
        os.killpg(os.getpgid(proc.pid), signal.SIGKILL)
    sys.exit(1)


def check_tasks_arg(value):
    try:
        t = json.loads(value)
        for t_name, t_data in t.items():
            if all(k in t_data for k in ("log", "cmd")):
                return t
            else:
                print("Some fields are missing in task JSON, working example:")
                pprint(tasks_example)
                sys.exit(1)
    except SystemExit:
        sys.exit(1)
    except:
        raise OptionValueError(
            "invalid value for tasks: \n%s" % (value))

if __name__ == '__main__':
    parser = OptionParser()

    parser.add_option("-t", "--tasks", dest="tasks",
                      help="JSON task list")

    (options, args) = parser.parse_args()
    tasks = check_tasks_arg(options.tasks)

    signal.signal(signal.SIGINT, sigint)
    signal.signal(signal.SIGTERM, sigint)

    for task_name, task_data in tasks.items():
        log = open(task_data["log"], "w")
        print("Starting task: %s \n    command: %s\n    log: %s" %
              (task_name, task_data["cmd"], task_data["log"]))
        processes[task_name] = subprocess.Popen(task_data["cmd"],
                                                stdout=log,
                                                stderr=log,
                                                shell=True,
                                                start_new_session=True)

    print("Checking tasks every %d seconds" % loop_check_delay)

    while processes:
        for task_name, p in list(processes.items()):
            if p.poll() is not None:
                print("Task: %s finished with code: %s" % (task_name,
                                                           p.returncode))
                del processes[task_name]
                if p.returncode != 0:
                    print("Task %s failed, killing everything" % task_name)
                    for t, proc in list(processes.items()):
                        print("Killing task %s" % t)
                        os.killpg(os.getpgid(proc.pid), signal.SIGKILL)
                    sys.exit(1)
            time.sleep(loop_check_delay)
