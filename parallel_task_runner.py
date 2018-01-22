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
    "Build compute": {
        "cmd": "ansible-playbook -i inventory build-win2016-compute.yaml",
        "log": "hv.log"
    },
    "Build devstack": {
        "cmd": "ansible-playbook -i inventory build-devstack.yaml",
        "log": "dv.log"
    }
}


# capture SIGINT (ctrl+c) and SIGTERM and kill everything if necessary
def sigint(s, f):
    print("Received signal: %s" % s)
    for t, proc in list(processes.items()):
        print("Killing task: %s" % t)
        os.killpg(os.getpgid(proc["process"].pid), signal.SIGKILL)
    sys.exit(1)


def create_process_element(task_name, task_data, attempt=1):
    log = open(task_data["log"], "w")
    result = {
        "process": create_process(task_data["cmd"], log),
        "attempt": attempt,
        "max": int(task_data["retry"]) if "retry" in task_data else 1
    }
    print("Starting task: %s \n    command: %s\n    log: %s\n    attempt: %s of %s" %
          (task_name, task_data["cmd"], task_data["log"], attempt, result["max"]))
    log.close()
    return result


def create_process(cmd, output_log, shell=True, start_new_session=True):
    return subprocess.Popen(
        cmd,
        stdout=output_log,
        stderr=output_log,
        start_new_session=start_new_session,
        shell=shell
    )


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
                      help="JSON task list", type=str)

    (options, args) = parser.parse_args()
    tasks = check_tasks_arg(options.tasks)

    signal.signal(signal.SIGINT, sigint)
    signal.signal(signal.SIGTERM, sigint)

    for task_name, task_data in tasks.items():
        processes[task_name] = create_process_element(task_name, task_data)

    print("Checking tasks every %d seconds" % loop_check_delay)

    while processes:
        for task_name, process in list(processes.items()):
            p = process["process"]
            if p.poll() is not None:
                print("Task: %s, attempt %s of %s, finished with code: %s" %
                      (task_name, process["attempt"], process["max"], p.returncode)
                      )

                if p.returncode != 0 and process["attempt"] < process["max"]:
                    processes[task_name] = create_process_element(
                        task_name, tasks[task_name], processes[task_name]["attempt"] + 1
                    )
                else:
                    del processes[task_name]
                    if p.returncode != 0:
                        print("Task %s failed, killing everything" % task_name)
                        for t, proc in list(processes.items()):
                            print("Killing task %s, attempt %s of %s" % (t, proc["attempt"], proc["max"]))
                            os.killpg(os.getpgid(proc["process"].pid), signal.SIGKILL)
                        sys.exit(1)
            time.sleep(loop_check_delay)
