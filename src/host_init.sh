#!/bin/bash

cd /root
MODE=${MODE:-""}
EFS=${EFS:-""}

cd /root

# Install aws
alias aws="/usr/local/aws-cli/v2/current/bin/aws"
export PATH="/usr/local/bin:/usr/bin:/usr/local/sbin:/usr/sbin:${PATH}"

# EFS
yum install fuse gcc python3 bash nfs-utils --quiet -y
sudo mkdir -p /mnt/efs
sudo chmod 777 /mnt/efs
if [[ ${MODE} == "oem_packages" ]]; then
    echo "Mode set to oem_packages. Setting EFS to read-only."
    sudo mount -t lustre -r -o relatime,flock $EFS /mnt/efs
else
    sudo mount -t lustre -o relatime,flock $EFS /mnt/efs
fi

# Make sure it is mounted before end script
sleep 10s

# Make the directories if it does not exist already
# These can be made regardless of the mode
# Reason why for so many if statements is to allow for new directories
# to be made without relying on if the user exists
make_directories() {
    main_DIR=$1

    if [ ! -d "$main_PATH/" ]; then
        sudo mkdir -p $main_DIR
        sudo chown -R mmc $main_DIR
        sudo chmod -R 777 $main_DIR
        sudo chgrp -R users $main_DIR
    fi
    if [ ! -d "$main_DIR/.pixi" ]; then
        sudo mkdir -p $main_DIR/.pixi
        sudo chown -R mmc $main_DIR/.pixi
        sudo chmod -R 777 $main_DIR/.pixi
        sudo chgrp -R users $main_DIR/.pixi
    fi

    if [ ! -d "$main_DIR/micromamba" ]; then
        sudo mkdir -p $main_DIR/micromamba
        sudo chown -R mmc $main_DIR/micromamba
        sudo chmod -R 777 $main_DIR/micromamba
        sudo chgrp -R users $main_DIR/micromamba
    fi

    if [ ! -d "$main_DIR/.config" ]; then
        sudo mkdir -p $main_DIR/.config
        sudo chown -R mmc $main_DIR/.config
        sudo chmod -R 777 $main_DIR/.config
        sudo chgrp -R users $main_DIR/.config
    fi

    if [ ! -d "$main_DIR/.cache" ]; then
        sudo mkdir -p $main_DIR/.cache
        sudo chown -R mmc $main_DIR/.cache
        sudo chmod -R 777 $main_DIR/.cache
        sudo chgrp -R users $main_DIR/.cache
    fi

    if [ ! -d "$main_DIR/.conda" ]; then
        sudo mkdir -p $main_DIR/.conda
        sudo chown -R mmc $main_DIR/.conda
        sudo chmod -R 777 $main_DIR/.conda
        sudo chgrp -R users $main_DIR/.conda
    fi

    if [ ! -f "$main_DIR/.condarc" ]; then
        # A file, not a directory
        sudo touch $main_DIR/.condarc
        sudo chown mmc $main_DIR/.condarc
        sudo chmod 777 $main_DIR/.condarc
        sudo chgrp users $main_DIR/.condarc
    fi

    if [ ! -d "$main_DIR/.ipython" ]; then
        sudo mkdir -p $main_DIR/.ipython
        sudo chown -R mmc $main_DIR/.ipython
        sudo chmod -R 777 $main_DIR/.ipython
        sudo chgrp -R users $main_DIR/.ipython
    fi

    if [ ! -d "$main_DIR/.jupyter" ]; then
        sudo mkdir -p $main_DIR/.jupyter
        sudo chown -R mmc $main_DIR/.jupyter
        sudo chmod -R 777 $main_DIR/.jupyter
        sudo chgrp -R users $main_DIR/.jupyter
    fi

    if [ ! -d "$main_DIR/.local" ]; then
        sudo mkdir -p $main_DIR/.local
        sudo chown -R mmc $main_DIR/.local
        sudo chmod -R 777 $main_DIR/.local
        sudo chgrp -R users $main_DIR/.local
    fi

    if [ ! -d "$main_DIR/.mamba/pkgs" ]; then
        sudo mkdir -p $main_DIR/.mamba/pkgs
        sudo chown -R mmc $main_DIR/.mamba
        sudo chmod -R 777 $main_DIR/.mamba
        sudo chgrp -R users $main_DIR/.mamba
    fi

    if [ ! -f "$main_DIR/.mambarc" ]; then
        # A file, not a directory
        sudo touch $main_DIR/.mambarc
        sudo chown mmc $main_DIR/.mambarc
        sudo chmod 777 $main_DIR/.mambarc
        sudo chgrp users $main_DIR/.mambarc
    fi

    # For Github setup
    if [ ! -d "$main_DIR/ghq" ]; then
        sudo mkdir -p $main_DIR/ghq
        sudo chown -R mmc $main_DIR/ghq
        sudo chmod -R 777 $main_DIR/ghq
        sudo chgrp -R users $main_DIR/ghq
    fi

    # Create .bashrc and .profile files
    if [ ! -f "$main_DIR/.bashrc" ]; then
        sudo touch $main_DIR/.bashrc
    fi
    if [ ! -f "$main_DIR/.profile" ]; then
        # Since .profile file will not change per mode, we can edit it here
        sudo touch $main_DIR/.profile
        tee ${efs_path}/.profile << EOF
# if running bash
if [ -n "\$BASH_VERSION" ]; then
# include .bashrc if it exists
if [ -f "\$HOME/.bashrc" ]; then
. "\$HOME/.bashrc"
fi
fi
EOF
    fi

    # For bashrc and profile, if they do exist, make sure they have the right permissions
    if [ -f "$main_DIR/.bashrc" ]; then
        sudo chown mmc $main_DIR/.bashrc
        sudo chmod 777 $main_DIR/.bashrc
        sudo chgrp users $main_DIR/.bashrc
    fi
    if [ -f "$main_DIR/.profile" ]; then
        sudo chown mmc $main_DIR/.profile
        sudo chmod 777 $main_DIR/.profile
        sudo chgrp users $main_DIR/.profile
    fi
}

# NOTE: Even if oem_packages does not need user directories, they are only made if they do not exist
# and will not be used anyway
# The same goes for shared directories for mount_packages
make_directories /mnt/efs/shared
make_directories /mnt/efs/$FLOAT_USER

# This section will rename the files under /opt/share/.pixi/bin/trampoline_configuration to point to the right location
# This is so non-admin users will be able to use shared packages
# Will run at the creation of any interactive job
for file in /mnt/efs/shared/.pixi/bin/trampoline_configuration/*.json; do
    sed -i 's|/home/ubuntu/.pixi|/mnt/efs/shared/.pixi|g' "$file"
done

######## SECTION ON JUPYTER SUSPENSION ########
if [[ $SUSPEND_FEATURE == "" ]] && { [[ $VMUI == "jupyter" ]] || [[ $VMUI == "jupyter-lab" ]]; }; then
    # Use nohup to run the Python script in the background
    echo "Turning on Jupyter suspension feature..."

    # Use nohup to run the Python script in the background
    # Grabbing job id of the job
    job_id=$(echo $FLOAT_JOB_ID)
    splitted="${job_id:0:2}/${job_id:2:2}/${job_id:4}"
    BASE_PATH="/mnt/memverge/slurm/work/$splitted"

    echo "BASEPATH: $BASE_PATH"
    nohup python3 - << 'EOF' > $BASE_PATH/python_output.log 2>&1 &

import subprocess
import sys
import os
import json
import time
import re
from datetime import datetime, timezone, timedelta
import threading
from dateutil.parser import isoparse

# Configuration variables

# Docker image name
docker_image_name = "quay.io/danielnachun/tmate-minimal"

# Paths and filenames
job_id=str(os.getenv("FLOAT_JOB_ID"))
splitted_job_id=f"{job_id[:2]}/{job_id[2:4]}/{job_id[4:]}"
base_path=f"/mnt/memverge/slurm/work/{splitted_job_id}/"

timestamp_str = datetime.now().strftime("%Y%m%d%H%M%S")
log_file_name = f'monitor_log_{timestamp_str}.txt'
output_json_name = 'output.json'

first_time_run_wait_time_seconds = int(os.getenv('FIRST_TIME_RUN_WAIT_TIME_SECONDS', '60'))
container_check_retry_interval_seconds = int(os.getenv('CONTAINER_CHECK_RETRY_INTERVAL_SECONDS', '60'))
max_container_check_attempts = int(os.getenv('MAX_CONTAINER_CHECK_ATTEMPTS', '20'))
max_file_check_attempts = int(os.getenv('MAX_FILE_CHECK_ATTEMPTS', '20'))
file_check_retry_interval_seconds = int(os.getenv('FILE_CHECK_RETRY_INTERVAL_SECONDS', '60'))
max_token_find_attempts = int(os.getenv('MAX_TOKEN_FIND_ATTEMPTS', '20'))
token_find_retry_interval_seconds = int(os.getenv('TOKEN_FIND_RETRY_INTERVAL_SECONDS', '60'))
allowable_idle_time_seconds = int(os.getenv('ALLOWABLE_IDLE_TIME_SECONDS', '7200'))                 # Default 2 hours
max_suspend_attempts = int(os.getenv('MAX_SUSPEND_ATTEMPTS', '3'))
sleep_time_between_suspend_attempts = int(os.getenv('SLEEP_TIME_BETWEEN_SUSPEND_ATTEMPTS', '60'))
idle_check_interval_seconds = int(os.getenv('IDLE_CHECK_INTERVAL_SECONDS', '60'))
max_jupyter_pid_attempts = int(os.getenv('MAX_JUPYTER_PID_ATTEMPTS', '20'))
jupyter_pid_retry_interval_seconds = int(os.getenv('JUPYTER_PID_RETRY_INTERVAL_SECONDS', '60'))
max_preparation_stage_time_seconds = int(os.getenv('MAX_PREPARATION_STAGE_TIME_SECONDS', '7200'))   # Default 2 hours
max_log_file_size_bytes = int(os.getenv('MAX_LOG_FILE_SIZE_BYTES', '10240000'))
max_log_files = int(os.getenv('MAX_LOG_FILES', '10'))

os.makedirs(base_path, exist_ok=True)

# Initialize the data dictionary
data = {
    'status': 'initializing',
    'container_id': None,
    'FLOAT_JOB_ID': None,
    'public_ip': None,
    'token': None,
    'last_notebook_modified_time': None,
    'idle_time': None,
    'action': 'starting_monitoring'
}

data['base_path'] = base_path

log_file_path = os.path.join(base_path, log_file_name)
log_file = open(log_file_path, 'a')

data = {
    'status': 'initializing',
    'container_id': None,
    'FLOAT_JOB_ID': None,
    'public_ip': None,
    'token': None,
    'last_notebook_modified_time': None,
    'idle_time': None,
    'action': 'starting_monitoring',
    'timestamp_from_latest_busy_status_check': None,
    'timestamp_from_latest_terminal_having_Child_Job_running_status_check': None,
    'last_activity_from_terminal': None,
    'used_time_for_idle_check': None,
    'time_diff': None,
    'latest_time': None,
    'latest_resume_time': None 
}

data['base_path'] = base_path

log_file_path = os.path.join(base_path, log_file_name)
log_file = open(log_file_path, 'a')

def log_message(message):
    global log_file, log_file_path
    timestamp = datetime.now(timezone.utc).isoformat()

    if os.path.isfile(log_file_path):
        log_file_size = os.path.getsize(log_file_path)
        if log_file_size >= max_log_file_size_bytes:
            log_file.close()
            timestamp_str = datetime.now().strftime("%Y%m%d%H%M%S")
            new_log_file_name = f"monitor_log_{timestamp_str}.txt"
            new_log_file_path = os.path.join(base_path, new_log_file_name)
            os.rename(log_file_path, new_log_file_path)
            log_file = open(log_file_path, 'a')
            log_files = [f for f in os.listdir(base_path) if f.startswith('monitor_log_') and f.endswith('.txt') and f != os.path.basename(log_file_path)]
            if len(log_files) > max_log_files:
                log_files.sort()
                files_to_delete = log_files[:-max_log_files]
                for file_name in files_to_delete:
                    os.remove(os.path.join(base_path, file_name))

    log_file.write(f"{timestamp} - {message}\n")
    log_file.flush()

output_json_path = os.path.join(base_path, output_json_name)
with open(output_json_path, 'w') as f:
    json.dump(data, f, indent=4)

def main_process():
    start_time = datetime.now(timezone.utc)
    data['script_start_time'] = start_time.isoformat()

    from time import sleep
    print("First-time run detected. Waiting for 1 minute before proceeding...")
    sleep(first_time_run_wait_time_seconds)

    container_ready = False
    attempts = 0
    while not container_ready and attempts < max_container_check_attempts:
        attempts += 1
        try:
            result = subprocess.run(
                ['sudo', 'podman', 'ps', '--filter', f'ancestor={docker_image_name}', '--format', '{{.ID}}'],
                stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, check=True
            )
            container_id = result.stdout.strip()
            if container_id:
                container_ready = True
                data['container_id'] = container_id
                log_message("Container is running.")
            else:
                log_message(f"Container not yet started, waiting {container_check_retry_interval_seconds} seconds before retrying...")
                time.sleep(container_check_retry_interval_seconds)
        except subprocess.CalledProcessError:
            log_message(f"Error checking container status, waiting {container_check_retry_interval_seconds} seconds before retrying...")
            time.sleep(container_check_retry_interval_seconds)

    if not container_ready:
        data['action'] = 'Container not running after maximum attempts. Exiting.'
        log_message("Container not running after maximum attempts. Exiting.")
        with open(output_json_path, 'w') as f:
            json.dump(data, f, indent=4)
        sys.exit(1)

    def get_env_var(var_name):
        try:
            result = subprocess.run(
                ['sudo', 'podman', 'exec', container_id, 'bash', '-c', f'echo ${var_name}'],
                stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, check=True
            )
            return result.stdout.strip()
        except subprocess.CalledProcessError:
            return ''

    float_job_id = get_env_var('FLOAT_JOB_ID')
    data['FLOAT_JOB_ID'] = float_job_id
    formatted_float_job_id = f"{float_job_id[:2]}/{float_job_id[2:4]}/{float_job_id[4:]}"
    data['formatted_FLOAT_JOB_ID'] = formatted_float_job_id
    file_path = f"/mnt/memverge/slurm/work/{formatted_float_job_id}/stderr.autosave"
    data['file_path'] = file_path

    with open(output_json_path, 'w') as f:
        json.dump(data, f, indent=4)

    file_exists = False
    attempts = 0
    while not file_exists and attempts < max_file_check_attempts:
        attempts += 1
        try:
            subprocess.run(['sudo', 'test', '-f', file_path], check=True)
            file_exists = True
            log_message(f"stderr.autosave file found after {attempts} attempts.")
        except subprocess.CalledProcessError:
            file_exists = False
            log_message(f"stderr.autosave file not found in attempt {attempts}. Waiting {file_check_retry_interval_seconds} seconds...")
            time.sleep(file_check_retry_interval_seconds)

    if not file_exists:
        data['file_exists'] = False
        data['jupyter_url'] = None
        data['token'] = None
        log_message("stderr.autosave file not found after maximum attempts. Exiting.")
        with open(output_json_path, 'w') as f:
            json.dump(data, f, indent=4)
        sys.exit(1)
    else:
        token_found = False
        attempts = 0
        while not token_found and attempts < max_token_find_attempts:
            attempts += 1
            try:
                result = subprocess.run(
                    ['sudo', 'cat', file_path],
                    stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, check=True
                )
                content = result.stdout
                match = re.search(r'(http://[^ ]*/lab\?token=[a-zA-Z0-9]+)', content)
                if match:
                    url = match.group(1)
                    data['jupyter_url'] = url
                    token_match = re.search(r'token=([a-zA-Z0-9]+)', url)
                    if token_match:
                        token = token_match.group(1)
                        data['token'] = token
                        token_found = True
                        log_message(f"Token found after {attempts} attempts.")
                    else:
                        data['token'] = None
                        log_message(f"Token not found in attempt {attempts}. Waiting {token_find_retry_interval_seconds} seconds...")
                        time.sleep(token_find_retry_interval_seconds)
                else:
                    data['jupyter_url'] = None
                    data['token'] = None
                    log_message(f"Token not found in attempt {attempts}. Waiting {token_find_retry_interval_seconds} seconds...")
                    time.sleep(token_find_retry_interval_seconds)
            except subprocess.CalledProcessError as e:
                data['jupyter_url'] = None
                data['token'] = None
                log_message(f"Error reading file in attempt {attempts}: {e}")
                time.sleep(token_find_retry_interval_seconds)
        if not token_found:
            data['action'] = 'Token not found after maximum attempts.'
            log_message("Token not found after maximum attempts. Exiting.")
            with open(output_json_path, 'w') as f:
                json.dump(data, f, indent=4)
            sys.exit(1)

    with open(output_json_path, 'w') as f:
        json.dump(data, f, indent=4)

    try:
        result = subprocess.run(['curl', '-s', 'ifconfig.me'], stdout=subprocess.PIPE, text=True, check=True)
        public_ip = result.stdout.strip()
        data['public_ip'] = public_ip
    except subprocess.CalledProcessError as e:
        data['public_ip'] = None
        log_message("Failed to get public IP. Exiting.")
        with open(output_json_path, 'w') as f:
            json.dump(data, f, indent=4)
        sys.exit(1)

    base_api_url = "http://127.0.0.1:8888"
    kernels_api_url = f"{base_api_url}/api/kernels"
    sessions_api_url = f"{base_api_url}/api/sessions"
    terminals_api_url = f"{base_api_url}/api/terminals"
    data['api_url'] = base_api_url
    data['kernels_curl_command'] = f"curl -sSLG {kernels_api_url} --data-urlencode 'token={data['token']}'"
    data['sessions_curl_command'] = f"curl -sSLG {sessions_api_url} --data-urlencode 'token={data['token']}'"

    preparation_stage = True

    latest_resume_datetime = datetime.now(timezone.utc)
    data['latest_resume_time'] = latest_resume_datetime.isoformat()
    with open(output_json_path, 'w') as f:
        json.dump(data, f, indent=4)

    while True:
        current_time = datetime.now(timezone.utc)
        data['current_time'] = current_time.isoformat()
        elapsed_time = current_time - start_time
        data['elapsed_time_since_start'] = str(elapsed_time)

        if preparation_stage and elapsed_time > timedelta(seconds=max_preparation_stage_time_seconds):
            preparation_stage = False
            log_message("Preparation stage time exceeded maximum allowed time. Exiting preparation stage.")
            float_job_id = data.get('FLOAT_JOB_ID')
            os.environ["HOME"] = "/root"
            cmd = ['/opt/memverge/bin/float', 'suspend', '-f', '-j', float_job_id]
            data['suspend_command'] = ' '.join(cmd)

            suspend_attempts = 0
            suspend_successful = False

            while suspend_attempts < max_suspend_attempts and not suspend_successful:
                suspend_attempts += 1
                try:
                    result = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, check=True)
                    suspend_output = result.stdout.strip()
                    data['suspend_output'] = suspend_output
                    if 'Suspend request has been submitted' in suspend_output:
                        data['action'] = 'Suspended job due to exceeding preparation stage time.'
                        log_message(f"Suspend attempt {suspend_attempts}: Suspended job due to exceeding preparation stage time.")
                        suspend_successful = True
                        break
                    else:
                        log_message(f"Suspend attempt {suspend_attempts}: Suspend command did not return success message. Retrying in {sleep_time_between_suspend_attempts} seconds...")
                        time.sleep(sleep_time_between_suspend_attempts)
                except subprocess.CalledProcessError as e:
                    data['suspend_error'] = f"Return code: {e.returncode}, stdout: {e.stdout.strip()}, stderr: {e.stderr.strip()}"
                    log_message(f"Suspend attempt {suspend_attempts}: Failed to suspend job. {data['suspend_error']}")
                    time.sleep(sleep_time_between_suspend_attempts)

            if not suspend_successful:
                data['action'] = 'Failed to suspend job after maximum attempts.'
                log_message("Failed to suspend job after maximum attempts.") 

            sys.exit(0)

        skip_idle_check = False

        try:
            result = subprocess.run(
                ['curl', '-sSLG', kernels_api_url, '--data-urlencode', f"token={data['token']}"],
                stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, check=True
            )
            kernels_json_output = result.stdout
            kernels_json_path = os.path.join(base_path, 'kernels.json')
            with open(kernels_json_path, 'w') as f:
                f.write(kernels_json_output)
            data['kernels'] = json.loads(kernels_json_output)
        except subprocess.CalledProcessError as e:
            data['kernels'] = None
            log_message("Failed to fetch kernels. Exiting.")
            sys.exit(1)

        try:
            result = subprocess.run(
                ['curl', '-sSLG', sessions_api_url, '--data-urlencode', f"token={data['token']}"],
                stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, check=True
            )
            sessions_json_output = result.stdout
            sessions_json_path = os.path.join(base_path, 'sessions.json')
            with open(sessions_json_path, 'w') as f:
                f.write(sessions_json_output)
            data['sessions'] = json.loads(sessions_json_output)
        except subprocess.CalledProcessError as e:
            data['sessions'] = None
            log_message("Failed to fetch sessions. Exiting.")
            sys.exit(1)

        try:
            result = subprocess.run(
                ['curl', '-sSLG', terminals_api_url, '--data-urlencode', f"token={data['token']}"],
                stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, check=True
            )
            terminals_json_output = result.stdout.strip()
            data['terminals'] = json.loads(terminals_json_output)
        except subprocess.CalledProcessError as e:
            data['terminals'] = []
            log_message("Failed to fetch terminals. Assuming no terminals.")

        # Check if there's a running child job from terminals
        terminal_child_running = False
        if data['terminals']:
            cmd = f"""
            sudo podman exec {data['container_id']} sh -c '
            ps -ef --forest | awk "
            /\\/usr\\/bin\\/sh -l/ {{parent_pids[\\$2] = 1}}
            {{
                if (\\$3 in parent_pids) {{
                print \\$2;
                exit;
                }}
            }}
            "
            '
            """

            result = subprocess.run(cmd, shell=True, text=True, capture_output=True)
            ps_output = result.stdout.replace(" ", "")

            if ps_output != "":
                terminal_child_running = True
                current_time = datetime.now(timezone.utc)
                data['timestamp_from_latest_terminal_having_Child_Job_running_status_check'] = current_time.isoformat()
                log_message("Detected child job in running, updated timestamp_from_latest_terminal_having_Child_Job_running_status_check.")
        else:
            data['terminals'] = []
            data['timestamp_from_latest_terminal_having_Child_Job_running_status_check'] = None

        terminal_last_activity_list = []
        for terminal in data['terminals']:
            t_last_activity = terminal.get('last_activity')
            if t_last_activity:
                t_last_activity_datetime = isoparse(t_last_activity)
                terminal_last_activity_list.append(t_last_activity_datetime)
        if terminal_last_activity_list:
            max_terminal_last_activity = max(terminal_last_activity_list)
            data['last_activity_from_terminal'] = max_terminal_last_activity.isoformat()
        else:
            data['last_activity_from_terminal'] = None

        notebook_relative_paths = [session['notebook']['path'] for session in data.get('sessions', [])]
        data['notebook_relative_paths_from_sessionAPI'] = notebook_relative_paths

        if notebook_relative_paths:
            jupyter_pid = None
            jupyter_working_directory = None
            pid_attempts = 0
            while not jupyter_pid and pid_attempts < max_jupyter_pid_attempts:
                pid_attempts += 1
                try:
                    cmd = [
                        'sudo', 'podman', 'exec', data['container_id'], 'bash', '-c',
                        "ps -ef | grep 'jupyter-lab' | grep -v grep | awk '{print $2}'"
                    ]
                    result = subprocess.run(
                        cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, check=True
                    )
                    pids = result.stdout.strip().split('\n')
                    if pids and pids[0]:
                        jupyter_pid = pids[0]
                        log_message(f"Found Jupyter PID: {jupyter_pid}")
                    else:
                        log_message(f"No Jupyter PID found, attempt {pid_attempts}, retrying in {jupyter_pid_retry_interval_seconds} seconds...")
                        time.sleep(jupyter_pid_retry_interval_seconds)
                except subprocess.CalledProcessError as e:
                    log_message(f"Error finding Jupyter PID: {e.stderr.strip()}, attempt {pid_attempts}, retrying in {jupyter_pid_retry_interval_seconds} seconds...")
                    time.sleep(jupyter_pid_retry_interval_seconds)

            if not jupyter_pid:
                log_message("Failed to find Jupyter PID after maximum attempts.")
                data['action'] = 'Failed to find Jupyter PID'
                jupyter_working_directory = None
            else:
                try:
                    cmd = [
                        'sudo', 'podman', 'exec', data['container_id'], 'bash', '-c',
                        f'ls -l /proc/{jupyter_pid}/cwd'
                    ]
                    result = subprocess.run(
                        cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, check=True
                    )
                    output = result.stdout.strip()
                    match = re.search(r'-> (.*)', output)
                    if match:
                        jupyter_working_directory = match.group(1)
                        log_message(f"Found Jupyter working directory: {jupyter_working_directory}")
                        data['jupyter_working_directory'] = jupyter_working_directory
                    else:
                        log_message("Failed to parse Jupyter working directory.")
                        data['jupyter_working_directory'] = None
                except subprocess.CalledProcessError as e:
                    log_message(f"Error getting Jupyter working directory: {e.stderr.strip()}")
                    data['jupyter_working_directory'] = None

            if jupyter_working_directory:
                notebook_paths = []
                for relative_path in notebook_relative_paths:
                    if relative_path.startswith('/'):
                        relative_path = relative_path[1:]
                    absolute_path = os.path.normpath(os.path.join(jupyter_working_directory, relative_path))
                    notebook_paths.append(absolute_path)
                data['notebook_paths'] = notebook_paths

                modification_times = []
                notebook_modification_times = []
                for notebook_path in notebook_paths:
                    try:
                        cmd = [
                            'sudo', 'podman', 'exec', data['container_id'], 'stat', '-c', '%Y', notebook_path
                        ]
                        result = subprocess.run(
                            cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, check=True
                        )
                        timestamp_str = result.stdout.strip()
                        if timestamp_str:
                            timestamp = datetime.fromtimestamp(int(timestamp_str), tz=timezone.utc)
                            modification_times.append(timestamp)
                            notebook_modification_times.append({
                                'path': notebook_path,
                                'modification_time': timestamp.isoformat()
                            })
                    except subprocess.CalledProcessError as e:
                        log_message(f"Failed to get modification time for {notebook_path}: {e.stderr.strip()}")
                data['notebook_modification_times'] = notebook_modification_times

                if modification_times:
                    last_notebook_modified_time = max(modification_times)
                    data['last_notebook_modified_time'] = last_notebook_modified_time.isoformat()
                else:
                    last_notebook_modified_time = None
                    data['last_notebook_modified_time'] = None
            else:
                data['notebook_paths'] = []
                data['notebook_modification_times'] = []
                data['last_notebook_modified_time'] = None
                log_message("Jupyter working directory not found. Skipping notebook modification time check.")
        else:
            data['notebook_paths'] = []
            data['notebook_modification_times'] = []
            data['last_notebook_modified_time'] = None
            log_message("No notebooks are currently open in the browser.")

        # Process kernels
        kernels = data.get('kernels', [])

        # Check if any kernels are busy or have connections
        any_kernel_active = False
        for kernel in kernels:
            connections = kernel.get('connections', 0)
            execution_state = kernel.get('execution_state')
            if connections > 0 or execution_state == 'busy':
                any_kernel_active = True
                preparation_stage = False  # User has started working
                break

        if preparation_stage and (data['terminals'] or terminal_child_running):
            preparation_stage = False

        if preparation_stage:
            data['action'] = 'Preparation stage: no action taken since no busy detection, elapsed time is less than max_preparation_stage_time_seconds.'
            log_message("Preparation stage: no action taken since no busy detection, elapsed time is less than max_preparation_stage_time_seconds.")
            skip_idle_check = True
        else:
            any_kernel_busy = any(kernel.get('execution_state') == 'busy' for kernel in kernels)

            if any_kernel_busy:
                data['timestamp_from_latest_busy_status_check'] = current_time.isoformat()
                data['action'] = 'At least one kernel is busy; no action taken.'
                log_message("At least one kernel is busy; no action taken.")
                skip_idle_check = True
            else:
                if terminal_child_running:
                    data['action'] = 'At least one terminal child process is running; no action taken.'
                    log_message("At least one terminal child process is running; no action taken.")
                    skip_idle_check = True

        if not skip_idle_check:
            times_to_compare = []

            if data.get('last_notebook_modified_time'):
                last_notebook_modified_time = isoparse(data['last_notebook_modified_time'])
                times_to_compare.append(last_notebook_modified_time)

            if data.get('last_activity_from_terminal'):
                terminal_last_activity_time = isoparse(data['last_activity_from_terminal'])
                times_to_compare.append(terminal_last_activity_time)

            if data.get('timestamp_from_latest_busy_status_check'):
                timestamp_busy = isoparse(data['timestamp_from_latest_busy_status_check'])
                times_to_compare.append(timestamp_busy)

            if data.get('timestamp_from_latest_terminal_having_Child_Job_running_status_check'):
                timestamp_terminal_job = isoparse(data['timestamp_from_latest_terminal_having_Child_Job_running_status_check'])
                times_to_compare.append(timestamp_terminal_job)

            if data.get('latest_resume_time'):
                latest_resume_time_dt = isoparse(data['latest_resume_time'])
                times_to_compare.append(latest_resume_time_dt)

            if times_to_compare:
                latest_time = max(times_to_compare)
                data['latest_time'] = latest_time.isoformat()
                data['used_time_for_idle_check'] = latest_time.isoformat()
                time_diff = current_time - latest_time
                data['time_diff'] = str(time_diff)
                data['idle_time'] = str(time_diff)
                allowable_idle_time = timedelta(seconds=allowable_idle_time_seconds)

                if time_diff > allowable_idle_time:
                    float_job_id = data.get('FLOAT_JOB_ID')
                    os.environ["HOME"] = "/root"
                    cmd = ['/opt/memverge/bin/float', 'suspend', '-f', '-j', float_job_id]
                    data['suspend_command'] = ' '.join(cmd)

                    suspend_attempts = 0
                    suspend_successful = False

                    while suspend_attempts < max_suspend_attempts and not suspend_successful:
                        suspend_attempts += 1
                        try:
                            result = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, check=True)
                            suspend_output = result.stdout.strip()
                            data['suspend_output'] = suspend_output
                            if 'Suspend request has been submitted' in suspend_output:
                                data['action'] = 'Suspended job due to inactivity.'
                                log_message(f"Suspend attempt {suspend_attempts}: Suspended job due to inactivity.")
                                suspend_successful = True
                                break
                            else:
                                log_message(f"Suspend attempt {suspend_attempts}: Suspend command did not return success message. Retrying in {sleep_time_between_suspend_attempts} seconds...")
                                time.sleep(sleep_time_between_suspend_attempts)
                        except subprocess.CalledProcessError as e:
                            data['suspend_error'] = f"Return code: {e.returncode}, stdout: {e.stdout.strip()}, stderr: {e.stderr.strip()}"
                            log_message(f"Suspend attempt {suspend_attempts}: Failed to suspend job. {data['suspend_error']}")
                            time.sleep(sleep_time_between_suspend_attempts)

                    if not suspend_successful:
                        data['action'] = 'Failed to suspend job after maximum attempts.'
                        log_message("Failed to suspend job after maximum attempts.")
                else:
                    time_diff_minutes = time_diff.total_seconds() / 60
                    data['action'] = f"Idle time not exceeded; Current idle time is {int(time_diff_minutes)} minutes; will check again in 1 minute."
                    log_message(f"Idle time not exceeded; Current idle time is {int(time_diff_minutes)} minutes; will check again in 1 minute.")
            else:
                data['action'] = 'No activity or modification time available; will check again in 1 minute.'
                log_message("No activity or modification time available; will check again in 1 minute.")

        for kernel in kernels:
            if '_last_activity_datetime_obj' in kernel:
                del kernel['_last_activity_datetime_obj']

        data_to_save = data.copy()
        with open(output_json_path, 'w') as f:
            json.dump(data_to_save, f, indent=4)
            
        

        time.sleep(idle_check_interval_seconds)

def run_in_background():
    log_message("Starting main process in background...")
    thread = threading.Thread(target=main_process)
    thread.start()
    return thread

if __name__ == "__main__":
    thread = run_in_background()
    thread.join()
    log_file.close()

EOF
fi
