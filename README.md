# csdig
Control Systems Digger digs into data found on Shodan.

Currently scanning via KNXnet/IP (Tunneling) is implemented. See **csdig-knx**.

## csdig-knx
csdig-knx is a Bash script: <code>csdig.sh</code>.

### Requirements
KNXmap fork found at https://github.com/uwedisch/knxmap because of several bug fixes found within the fork.

python-shodan installed with <code>sudo apt-get python-shodan</code>.

csvtool installed with <code>sudo apt-get csvtool</code>.
  
### Execution
Called without any parameter csdig-knx searches on Shodan for the keyword <code>knx</code> and traverses thru all results.  Each result, i.e. KNXnet/IP (Tunneling) aware controller, is scanned for reachable KNX TP devices.  Each reachable KNX TP device is also scanned.  Together all output is written to the directory <code>data</code>.

If a parameter is provided while calling csdig-knx this parameter is used as search key.

### Configuration
Configuration is done via file <code>csdig.conf</code>.

### Compatibility
Tested on Kali Linux 2020.1 Release and on Ubuntu 16.04 LTS.
