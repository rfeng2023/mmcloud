#!/bin/bash

cd /root

# Install aws
alias aws="/usr/local/aws-cli/v2/current/bin/aws"
export PATH="/usr/local/bin:/usr/bin:/usr/local/sbin:/usr/sbin:${PATH}"

# EFS
yum install fuse gcc python3 bash nfs-utils --quiet -y
sudo mkdir -p /mnt/efs
sudo chmod 777 /mnt/efs
sudo mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport 10.1.10.236:/ /mnt/efs

# Make sure it is mounted before end script
sleep 10s

# Make the directories if it does not exist already
# Reason why for so many if statements is to allow for new directories
# to be made without relying on if the user exists
if [ ! -d "/opt/shared" ]; then
    sudo mkdir -p /opt/shared
    sudo chown -R mmc /opt/shared
    sudo chmod -R 777 /opt/shared
    sudo chgrp -R users /opt/shared
fi
if [ ! -d "/mnt/efs/$FLOAT_USER/" ]; then
    sudo mkdir -p /mnt/efs/$FLOAT_USER
    sudo chown -R mmc /mnt/efs/$FLOAT_USER
    sudo chmod -R 777 /mnt/efs/$FLOAT_USER
    sudo chgrp -R users /mnt/efs/$FLOAT_USER
fi
if [ ! -d "/mnt/efs/$FLOAT_USER/.pixi" ]; then
    sudo mkdir -p /mnt/efs/$FLOAT_USER/.pixi
    sudo chown -R mmc /mnt/efs/$FLOAT_USER/.pixi
    sudo chmod -R 777 /mnt/efs/$FLOAT_USER/.pixi
    sudo chgrp -R users /mnt/efs/$FLOAT_USER/.pixi
fi

if [ ! -d "/mnt/efs/$FLOAT_USER/micromamba" ]; then
    sudo mkdir -p /mnt/efs/$FLOAT_USER/micromamba
    sudo chown -R mmc /mnt/efs/$FLOAT_USER/micromamba
    sudo chmod -R 777 /mnt/efs/$FLOAT_USER/micromamba
    sudo chgrp -R users /mnt/efs/$FLOAT_USER/micromamba
fi

if [ ! -d "/mnt/efs/$FLOAT_USER/.config" ]; then
    sudo mkdir -p /mnt/efs/$FLOAT_USER/.config
    sudo chown -R mmc /mnt/efs/$FLOAT_USER/.config
    sudo chmod -R 777 /mnt/efs/$FLOAT_USER/.config
    sudo chgrp -R users /mnt/efs/$FLOAT_USER/.config
fi

if [ ! -d "/mnt/efs/$FLOAT_USER/.cache" ]; then
    sudo mkdir -p /mnt/efs/$FLOAT_USER/.cache
    sudo chown -R mmc /mnt/efs/$FLOAT_USER/.cache
    sudo chmod -R 777 /mnt/efs/$FLOAT_USER/.cache
    sudo chgrp -R users /mnt/efs/$FLOAT_USER/.cache
fi

if [ ! -d "/mnt/efs/$FLOAT_USER/.conda" ]; then
    sudo mkdir -p /mnt/efs/$FLOAT_USER/.conda
    sudo chown -R mmc /mnt/efs/$FLOAT_USER/.conda
    sudo chmod -R 777 /mnt/efs/$FLOAT_USER/.conda
    sudo chgrp -R users /mnt/efs/$FLOAT_USER/.conda
fi

if [ ! -d "/mnt/efs/$FLOAT_USER/.condarc" ]; then
    # A file, not a directory
    sudo touch /mnt/efs/$FLOAT_USER/.condarc
    sudo chown mmc /mnt/efs/$FLOAT_USER/.condarc
    sudo chmod 777 /mnt/efs/$FLOAT_USER/.condarc
    sudo chgrp users /mnt/efs/$FLOAT_USER/.condarc
fi

if [ ! -d "/mnt/efs/$FLOAT_USER/.ipython" ]; then
    sudo mkdir -p /mnt/efs/$FLOAT_USER/.ipython
    sudo chown -R mmc /mnt/efs/$FLOAT_USER/.ipython
    sudo chmod -R 777 /mnt/efs/$FLOAT_USER/.ipython
    sudo chgrp -R users /mnt/efs/$FLOAT_USER/.ipython
fi

if [ ! -d "/mnt/efs/$FLOAT_USER/.jupyter" ]; then
    sudo mkdir -p /mnt/efs/$FLOAT_USER/.jupyter
    sudo chown -R mmc /mnt/efs/$FLOAT_USER/.jupyter
    sudo chmod -R 777 /mnt/efs/$FLOAT_USER/.jupyter
    sudo chgrp -R users /mnt/efs/$FLOAT_USER/.jupyter
fi

if [ ! -d "/mnt/efs/$FLOAT_USER/.local" ]; then
    sudo mkdir -p /mnt/efs/$FLOAT_USER/.local
    sudo chown -R mmc /mnt/efs/$FLOAT_USER/.local
    sudo chmod -R 777 /mnt/efs/$FLOAT_USER/.local
    sudo chgrp -R users /mnt/efs/$FLOAT_USER/.local
fi

if [ ! -d "/mnt/efs/$FLOAT_USER/.mamba/pkgs" ]; then
    sudo mkdir -p /mnt/efs/$FLOAT_USER/.mamba/pkgs
    sudo chown -R mmc /mnt/efs/$FLOAT_USER/.mamba
    sudo chmod -R 777 /mnt/efs/$FLOAT_USER/.mamba
    sudo chgrp -R users /mnt/efs/$FLOAT_USER/.mamba
fi

if [ ! -d "/mnt/efs/$FLOAT_USER/.mambarc" ]; then
    # A file, not a directory
    sudo touch /mnt/efs/$FLOAT_USER/.mambarc
    sudo chown mmc /mnt/efs/$FLOAT_USER/.mambarc
    sudo chmod 777 /mnt/efs/$FLOAT_USER/.mambarc
    sudo chgrp users /mnt/efs/$FLOAT_USER/.mambarc
fi

# For bashrc and profile, if they do exist, make sure they have the right permissions
# for this setup
if [ -d "/mnt/efs/$FLOAT_USER/.bashrc" ]; then
    sudo chown mmc /mnt/efs/$FLOAT_USER/.bashrc
    sudo chmod 777 /mnt/efs/$FLOAT_USER/.bashrc
    sudo chgrp users /mnt/efs/$FLOAT_USER/.bashrc
fi
if [ -d "/mnt/efs/$FLOAT_USER/.profile" ]; then
    sudo chown mmc /mnt/efs/$FLOAT_USER/.profile
    sudo chmod 777 /mnt/efs/$FLOAT_USER/.profile
    sudo chgrp users /mnt/efs/$FLOAT_USER/.profile
fi

# This section will rename the files under /opt/share/.pixi/bin/trampoline_configuration to point to the right location
# This is so non-admin users will be able to use shared packages
for file in /mnt/efs/shared/.pixi/bin/trampoline_configuration/*.json; do
    sed -i 's|/home/ubuntu/.pixi|/opt/shared/.pixi|g' "$file"
done

######## SECTION ON JUPYTER SUSPENSION ########
if [[ $VMUI == "jupyter" ]] || [[ $VMUI == "jupyter-lab" ]]; then
    # Use nohup to run the Python script in the background
    nohup python3 - << 'EOF' > /tmp/python_output.log 2>&1 &

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
base_path = '/tmp/'  # Base path for storing files

# Generate timestamp for log file names
timestamp_str = datetime.now().strftime("%Y%m%d%H%M%S")
log_file_name = f'monitor_log_{timestamp_str}.txt'
output_json_name = 'output.json'

# First-time run wait time in seconds
first_time_run_wait_time_seconds = int(os.getenv('FIRST_TIME_RUN_WAIT_TIME_SECONDS', '60'))  # Default to 1 minute

# Container check retry interval in seconds
container_check_retry_interval_seconds = int(os.getenv('CONTAINER_CHECK_RETRY_INTERVAL_SECONDS', '60'))  # Default to 1 minute

# Maximum attempts to check for container readiness and file existence
max_container_check_attempts = int(os.getenv('MAX_CONTAINER_CHECK_ATTEMPTS', '20'))
max_file_check_attempts = int(os.getenv('MAX_FILE_CHECK_ATTEMPTS', '20'))

# File existence check retry interval in seconds
file_check_retry_interval_seconds = int(os.getenv('FILE_CHECK_RETRY_INTERVAL_SECONDS', '60'))  # Default to 1 minute

# Maximum attempts to find the token
max_token_find_attempts = int(os.getenv('MAX_TOKEN_FIND_ATTEMPTS', '20'))

# Token find retry interval in seconds
token_find_retry_interval_seconds = int(os.getenv('TOKEN_FIND_RETRY_INTERVAL_SECONDS', '60'))  # Default to 1 minute

# Allowable idle time before suspending job
allowable_idle_time_seconds = int(os.getenv('ALLOWABLE_IDLE_TIME_SECONDS', '7200'))  # Default to 2 hours

# Maximum suspend attempts
max_suspend_attempts = int(os.getenv('MAX_SUSPEND_ATTEMPTS', '3'))

# Sleep time between suspend attempts in seconds
sleep_time_between_suspend_attempts = int(os.getenv('SLEEP_TIME_BETWEEN_SUSPEND_ATTEMPTS', '60'))  # Default to 1 minute

# Idle check interval in seconds
idle_check_interval_seconds = int(os.getenv('IDLE_CHECK_INTERVAL_SECONDS', '60'))  # Default to 1 minute

# Maximum attempts to get Jupyter PID
max_jupyter_pid_attempts = int(os.getenv('MAX_JUPYTER_PID_ATTEMPTS', '20'))

# Jupyter PID check retry interval in seconds
jupyter_pid_retry_interval_seconds = int(os.getenv('JUPYTER_PID_RETRY_INTERVAL_SECONDS', '60'))  # Default to 1 minute

# Maximum preparation stage time before automatic suspension
max_preparation_stage_time_seconds = int(os.getenv('MAX_PREPARATION_STAGE_TIME_SECONDS', '1800'))  

# Maximum log file size in bytes (e.g., 10MB)
max_log_file_size_bytes = int(os.getenv('MAX_LOG_FILE_SIZE_BYTES', '10240000'))  # Default to 10MB

# Maximum number of log files to keep
max_log_files = int(os.getenv('MAX_LOG_FILES', '10'))

# Ensure the base_path exists
os.makedirs(base_path, exist_ok=True)

# Initialize the data dictionary with some default values
data = {
    'status': 'initializing',
    'container_id': None,
    'FLOAT_JOB_ID': None,
    'public_ip': None,
    'token': None,
    'last_activity_time': None,
    'last_notebook_modified_time': None,
    'idle_time': None,
    'action': 'starting_monitoring'
}

# Open a log file for writing messages
log_file_path = os.path.join(base_path, log_file_name)
log_file = open(log_file_path, 'a')

# Function to log messages to the file
def log_message(message):
    global log_file, log_file_path

    timestamp = datetime.now(timezone.utc).isoformat()

    # Check the size of the log file
    if os.path.isfile(log_file_path):
        log_file_size = os.path.getsize(log_file_path)
        if log_file_size >= max_log_file_size_bytes:
            # Close current log file
            log_file.close()
            # Rename the log file with timestamp
            timestamp_str = datetime.now().strftime("%Y%m%d%H%M%S")
            new_log_file_name = f"monitor_log_{timestamp_str}.txt"
            new_log_file_path = os.path.join(base_path, new_log_file_name)
            os.rename(log_file_path, new_log_file_path)
            # Open a new log file
            log_file = open(log_file_path, 'a')
            # Manage log files to keep at most max_log_files
            # Get list of log files excluding the current one
            log_files = [f for f in os.listdir(base_path) if f.startswith('monitor_log_') and f.endswith('.txt') and f != os.path.basename(log_file_path)]
            if len(log_files) > max_log_files:
                # Sort the log files by name (since the timestamp in the name is sortable)
                log_files.sort()
                # Delete the oldest files
                files_to_delete = log_files[:-max_log_files]
                for file_name in files_to_delete:
                    os.remove(os.path.join(base_path, file_name))

    # Write the log message
    log_file.write(f"{timestamp} - {message}\n")
    log_file.flush()

# Write the initial data to output.json
output_json_path = os.path.join(base_path, output_json_name)
with open(output_json_path, 'w') as f:
    json.dump(data, f, indent=4)

def main_process():
    # Record the script start time
    start_time = datetime.now(timezone.utc)
    data['script_start_time'] = start_time.isoformat()

    # Wait until the container is running
    # **First-time run logic**
    from time import sleep
    print("First-time run detected. Waiting for 1 minute before proceeding...")
    sleep(first_time_run_wait_time_seconds)  # Wait for the configured time

    container_ready = False
    attempts = 0
    while not container_ready and attempts < max_container_check_attempts:
        attempts += 1
        # Check if the container is running
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

    # Function to get environment variables from the container
    def get_env_var(var_name):
        try:
            result = subprocess.run(
                ['sudo', 'podman', 'exec', container_id, 'bash', '-c', f'echo ${var_name}'],
                stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, check=True
            )
            return result.stdout.strip()
        except subprocess.CalledProcessError:
            return ''

    # Retrieve FLOAT_JOB_ID
    float_job_id = get_env_var('FLOAT_JOB_ID')
    data['FLOAT_JOB_ID'] = float_job_id

    # Format the FLOAT_JOB_ID with slashes
    formatted_float_job_id = f"{float_job_id[:2]}/{float_job_id[2:4]}/{float_job_id[4:]}"
    data['formatted_FLOAT_JOB_ID'] = formatted_float_job_id

    # Construct the file path
    file_path = f"/mnt/memverge/slurm/work/{formatted_float_job_id}/stderr.autosave"
    data['file_path'] = file_path

    # Update output.json after retrieving environment variables
    with open(output_json_path, 'w') as f:
        json.dump(data, f, indent=4)

    # Loop to wait for the stderr.autosave file to exist
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
        # Update output.json
        with open(output_json_path, 'w') as f:
            json.dump(data, f, indent=4)
        sys.exit(1)
    else:
        # Loop to wait for the token to appear in the file
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
                # Use regex to find the URL
                match = re.search(r'(http://[^ ]*/lab\?token=[a-zA-Z0-9]+)', content)
                if match:
                    url = match.group(1)
                    data['jupyter_url'] = url
                    # Extract the token from the URL
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
            # Update output.json
            with open(output_json_path, 'w') as f:
                json.dump(data, f, indent=4)
            sys.exit(1)

    # Update output.json with the new data
    with open(output_json_path, 'w') as f:
        json.dump(data, f, indent=4)

    # Continue only if the token was found
    # Get the public IP
    try:
        result = subprocess.run(['curl', '-s', 'ifconfig.me'], stdout=subprocess.PIPE, text=True, check=True)
        public_ip = result.stdout.strip()
        data['public_ip'] = public_ip
    except subprocess.CalledProcessError as e:
        data['public_ip'] = None
        log_message("Failed to get public IP. Exiting.")
        # Update output.json
        with open(output_json_path, 'w') as f:
            json.dump(data, f, indent=4)
        sys.exit(1)

    # Construct the API URLs
    #base_api_url = f"{public_ip}:8888"
    base_api_url = "http://127.0.0.1:8888"

    kernels_api_url = f"{base_api_url}/api/kernels"
    sessions_api_url = f"{base_api_url}/api/sessions"
    data['api_url'] = base_api_url

    # Save the curl commands used to call the APIs
    data['kernels_curl_command'] = f"curl -sSLG {kernels_api_url} --data-urlencode 'token={data['token']}'"
    data['sessions_curl_command'] = f"curl -sSLG {sessions_api_url} --data-urlencode 'token={data['token']}'"

    # Update output.json with the new data
    with open(output_json_path, 'w') as f:
        json.dump(data, f, indent=4)

    # Initialize preparation_stage to True and timestamp_from_latest_busy_status_check to None
    preparation_stage = True # Only set to False within while loop.
    data['timestamp_from_latest_busy_status_check'] = None

    # Start the monitoring loop
    while True:
        # Get current time
        current_time = datetime.now(timezone.utc)
        data['current_time'] = current_time.isoformat()

        # Calculate elapsed time since script started
        elapsed_time = current_time - start_time # elapsed_time is a datetime.timedelta object
        data['elapsed_time_since_start'] = str(elapsed_time)

        # Check if preparation stage time has exceeded maximum allowed time
        if preparation_stage and elapsed_time > timedelta(seconds=max_preparation_stage_time_seconds): # must add timedelta, otherwise TypeError
            preparation_stage = False
            log_message("Preparation stage time exceeded maximum allowed time. Exiting preparation stage.")
            # Execute suspend command immediately
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
                        break  # Exit the loop
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

            # Save the collected data to a JSON file
            data_to_save = data.copy()
            with open(output_json_path, 'w') as f:
                json.dump(data_to_save, f, indent=4)

            # Since we've suspended the job, we can exit the script
            sys.exit(0) # The program will terminate here, so saving the data needs to be completed before exiting.

        # Initialize skip_idle_check flag
        skip_idle_check = False # when we will execute this line, when elapsed_time is less than max_preparation_stage_time_seconds

        # Call the kernels API using curl
        try:
            result = subprocess.run(
                ['curl', '-sSLG', kernels_api_url, '--data-urlencode', f"token={data['token']}"],
                stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, check=True
            )
            kernels_json_output = result.stdout
            # Save the output to a JSON file
            kernels_json_path = os.path.join(base_path, 'kernels.json')
            with open(kernels_json_path, 'w') as f:
                f.write(kernels_json_output)
            # Include kernels data in the main JSON
            data['kernels'] = json.loads(kernels_json_output)
        except subprocess.CalledProcessError as e:
            data['kernels'] = None
            log_message("Failed to fetch kernels. Exiting.")
            sys.exit(1)

        # Call the sessions API to get notebook paths
        try:
            result = subprocess.run(
                ['curl', '-sSLG', sessions_api_url, '--data-urlencode', f"token={data['token']}"],
                stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, check=True
            )
            sessions_json_output = result.stdout
            # Save the output to a JSON file
            sessions_json_path = os.path.join(base_path, 'sessions.json')
            with open(sessions_json_path, 'w') as f:
                f.write(sessions_json_output)
            # Include sessions data in the main JSON
            data['sessions'] = json.loads(sessions_json_output)
        except subprocess.CalledProcessError as e:
            data['sessions'] = None
            log_message("Failed to fetch sessions. Exiting.")
            sys.exit(1)

        # Get notebook relative paths from sessions
        notebook_relative_paths = [session['notebook']['path'] for session in data.get('sessions', [])] # check the json output log file to better understand this line
        data['notebook_relative_paths_from_sessionAPI'] = notebook_relative_paths

        if notebook_relative_paths:
            # Try to get the Jupyter PID and working directory
            jupyter_pid = None
            jupyter_working_directory = None

            # Try to get the Jupyter PID
            pid_attempts = 0
            while not jupyter_pid and pid_attempts < max_jupyter_pid_attempts:
                pid_attempts += 1
                try:
                    cmd = [
                        'sudo', 'podman', 'exec', container_id, 'bash', '-c',
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
                # Get the Jupyter working directory
                # you also can use pwdx comamnd to display the current working directory of each process.
                try:
                    cmd = [
                        'sudo', 'podman', 'exec', container_id, 'bash', '-c',
                        f'ls -l /proc/{jupyter_pid}/cwd'
                    ]
                    result = subprocess.run(
                        cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, check=True
                    )
                    output = result.stdout.strip()
                    # The output is like: lrwxrwxrwx 1 jovyan users 0 Oct 23 22:05 /proc/739/cwd -> /home/jovyan/handson-tutorials/contents
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
                # Combine working directory and relative paths to get absolute paths
                notebook_paths = []
                for relative_path in notebook_relative_paths:
                    # Remove leading '/' if present
                    if relative_path.startswith('/'):
                        relative_path = relative_path[1:]
                    absolute_path = os.path.normpath(os.path.join(jupyter_working_directory, relative_path))
                    notebook_paths.append(absolute_path)
                data['notebook_paths'] = notebook_paths

                # Retrieve modification timestamps of notebooks
                # A list to store the modification timestamps (as datetime objects) of all the notebooks found in the Jupyter working directory
                modification_times = []
                # A list containing multiple dictionaries. Each dictionary represents information about a notebook file, including file path and modification time.
                notebook_modification_times = []
                for notebook_path in notebook_paths:
                    try:
                        cmd = [
                            'sudo', 'podman', 'exec', container_id, 'stat', '-c', '%Y', notebook_path
                        ]
                        result = subprocess.run(
                            cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, check=True
                        )
                        timestamp_str = result.stdout.strip()
                        if timestamp_str:
                            # Convert a UNIX timestamp string into a datetime object
                            # The int(timestamp_str) converts the timestamp_str (a string representation of a UNIX timestamp) into an integer.
                            # datetime.fromtimestamp(...) converts the UNIX timestamp (seconds since the epoch, typically January 1, 1970) into a Python datetime object.
                            # The tz=timezone.utc argument ensures that the resulting datetime object is in UTC time.
                            timestamp = datetime.fromtimestamp(int(timestamp_str), tz=timezone.utc)
                            modification_times.append(timestamp)
                            # isoparse(timestamp.isoformat()) converts the datetime object back to an ISO 8601 string.
                            # For example, convert "2024, 11, 1, 12, 30, 45" to "2024-11-01T12:30:45+00:00".
                            notebook_modification_times.append({
                                'path': notebook_path,
                                'modification_time': timestamp.isoformat()
                            })
                    except subprocess.CalledProcessError as e:
                        log_message(f"Failed to get modification time for {notebook_path}: {e.stderr.strip()}")
                # Assigns the notebook_modification_times list to the key 'notebook_modification_times' in the data dictionary.
                data['notebook_modification_times'] = notebook_modification_times

                # Find the most recent modification time
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

        last_activity_time = None

        # Check if any kernels have connections > 0 or execution_state == 'busy'
        any_kernel_active = False
        for kernel in kernels:
            connections = kernel.get('connections', 0)
            execution_state = kernel.get('execution_state')
            if connections > 0 or execution_state == 'busy':
                any_kernel_active = True
                preparation_stage = False  # User has started working
                break  # No need to check further

        # If in preparation stage and no kernels are active
        if preparation_stage:
            data['action'] = 'Preparation stage: no action taken since no connection and no busy detection, elapsed time is less than max_preparation_stage_time_seconds.'
            log_message("Preparation stage: no action taken since no connection and no busy detection, elapsed time is less than max_preparation_stage_time_seconds.")
            skip_idle_check = True  # Skip idle check

        else:
            # Check if any of the kernels are busy
            any_kernel_busy = any(kernel.get('execution_state') == 'busy' for kernel in kernels)

            if any_kernel_busy:
                # Update the timestamp_from_latest_busy_status_check to the current time
                data['timestamp_from_latest_busy_status_check'] = current_time.isoformat()
                data['action'] = 'At least one kernel is busy; no action taken.'
                log_message("At least one kernel is busy; no action taken.")
                skip_idle_check = True  # Set flag to skip idle time check
            else:
                # Proceed to check idle time based on last activity
                # Extract last_activity from all kernels
                for kernel in kernels:
                    last_activity = kernel.get('last_activity')
                    if last_activity:
                        last_activity_datetime = isoparse(last_activity)
                        kernel['last_activity_datetime'] = last_activity_datetime.isoformat()
                        kernel['_last_activity_datetime_obj'] = last_activity_datetime
                    else:
                        kernel['last_activity_datetime'] = None
                        kernel['_last_activity_datetime_obj'] = datetime.min.replace(tzinfo=timezone.utc)

                # Get the most recent last_activity_time among all kernels
                last_activity_times = [kernel.get('_last_activity_datetime_obj') for kernel in kernels if kernel.get('_last_activity_datetime_obj')]
                if last_activity_times:
                    last_activity_time = max(last_activity_times)
                    data['last_activity_time'] = last_activity_time.isoformat()
                else:
                    last_activity_time = None
                    data['last_activity_time'] = None
                skip_idle_check = False

        if not skip_idle_check:
            # Proceed with idle time check
            # Decide which time to use for idle time calculation
            times_to_compare = []
            # if last_activity_time:
            #     times_to_compare.append(last_activity_time)  # datetime object
            if data.get('last_notebook_modified_time'):
                last_notebook_modified_time = isoparse(data['last_notebook_modified_time'])  # parse to datetime
                times_to_compare.append(last_notebook_modified_time)
            if data.get('timestamp_from_latest_busy_status_check'):
                timestamp_busy = isoparse(data['timestamp_from_latest_busy_status_check'])
                times_to_compare.append(timestamp_busy)

            if times_to_compare:
                # Get the most recent time
                latest_time = max(times_to_compare)
                data['used_time_for_idle_check'] = latest_time.isoformat()

                # Calculate time difference
                time_diff = current_time - latest_time
                data['idle_time'] = str(time_diff)

                # Allowable idle time
                allowable_idle_time = timedelta(seconds=allowable_idle_time_seconds)

                if time_diff > allowable_idle_time:
                    # Now execute the suspend command with retry logic
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
                                break  # Exit the loop
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
                    data['action'] = 'Idle time not exceeded; will check again in 1 minute.'
                    log_message("Idle time not exceeded; will check again in 1 minute.")
            else:
                data['action'] = 'No activity or modification time available; will check again in 1 minute.'
                log_message("No activity or modification time available; will check again in 1 minute.")
        else:
            # Kernel is busy or in preparation stage, we skip idle time check
            pass

        # Remove the datetime objects before saving to JSON
        for kernel in kernels:
            if '_last_activity_datetime_obj' in kernel:
                del kernel['_last_activity_datetime_obj']

        # Save the collected data to a JSON file
        data_to_save = data.copy()
        with open(output_json_path, 'w') as f:
            json.dump(data_to_save, f, indent=4)

        # Wait for the next check
        time.sleep(idle_check_interval_seconds)

def run_in_background():
    log_message("Starting main process in background...")
    # Create a thread to run the main process
    thread = threading.Thread(target=main_process)
    thread.start()
    return thread

if __name__ == "__main__":
    # Run the background process
    thread = run_in_background()

    # Wait for the background thread to finish
    thread.join()  # Ensures the main process waits for the thread to complete before proceeding

    # Close the log file after the thread completes its work
    log_file.close()

EOF
fi
