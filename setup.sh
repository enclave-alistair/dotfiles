#!/bin/bash
set -euo pipefail

curl -fsSL https://packages.enclave.io/apt/enclave.stable.gpg | sudo apt-key add -
curl -fsSL https://packages.enclave.io/apt/enclave.stable.list | sudo tee /etc/apt/sources.list.d/enclave.stable.list
sudo apt-get update
sudo apt-get install enclave -y

# Add init.d file so we can treat enclave like a service
cat <<-EOF | sudo tee /etc/init.d/enclave >/dev/null
#!/bin/sh
### BEGIN INIT INFO
# Provides:
# Required-Start:    \$remote_fs \$syslog
# Required-Stop:     \$remote_fs \$syslog
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Start daemon at boot time
# Description:       Enable service provided by daemon.
### END INIT INFO

dir="\$HOME"
name="enclave"
pid_file="/var/run/\$name.pid"
stdout_log="/var/log/\$name.log"
stderr_log="/var/log/\$name.err"

get_pid() {
    cat "\$pid_file"
}

is_running() {
    [ -f "\$pid_file" ] && ps -p `get_pid` > /dev/null 2>&1
}

case "\$1" in
    start)
    if is_running; then
        echo "Already started"
    else
        echo "Starting \$name"
        cd "\$dir"

        sudo start-stop-daemon --start --oknodo --background --user root --make-pidfile --pidfile \$pid_file --exec /usr/bin/enclave -- supervisor-service
    fi
    ;;
    stop)
    if true; then
        echo -n "Stopping \$name.."
        
        sudo start-stop-daemon --quiet --oknodo --stop --retry 5 \\
                               --user root --remove-pidfile --pidfile \$pid_file \\
                               --exec /usr/bin/enclave --signal KILL
        
        if is_running; then
            echo "Not stopped; may still be shutting down or shutdown may have failed"
            exit 1
        else
            echo "Stopped"
        fi
    else
        echo "Not running"
    fi
    ;;
    restart)
    \$0 stop
    if is_running; then
        echo "Unable to stop, will not attempt to start"
        exit 1
    fi
    \$0 start
    ;;
    status)
    if is_running; then
        echo "Running"
    else
        echo "Stopped"
        exit 1
    fi
    ;;
    *)
    echo "Usage: \$0 {start|stop|restart|status}"
    exit 1
    ;;
esac

exit 0

EOF

sudo chmod +x /etc/init.d/enclave
sudo update-rc.d enclave defaults
sudo service enclave start

# We can auto-enrol if an environment variable is available.
if [[ ! -z "${ENCLAVE_ENROLMENT_KEY:-}" ]]; then
sudo enclave enrol 
fi