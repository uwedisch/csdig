# csdig
Control Systems Digger digs into data found on Shodan.

Currently scanning via KNXnet/IP (Tunneling) is implemented via **csdig-knx**. csdig-knx is used for reconnaissance and mapping of KNX TP networks behind KNXnet/IP (Tunneling) controllers.

## csdig-knx
csdig-knx is a Bash script: <code>csdig.sh</code>.

### Intention
Scanning with csdig-knx is more robust than scanning with KNXmap itself because intention of csdig-knx is to circumvent the weaknesses of communication over an unreliable protocol like UDP. Obstacles while scanning in the wild are:
* Missing compatibility (not all KNXnet/IP / KNX TP devices are certified and therefore do not stick to the definitions)
* High latencies (running into timeouts)
* Network congestions (loss of datagrams)
* KNXmap itself isn't perfect (knwon issues)

The intention of csdig-knx is also to go deeper into KNX networks than Shodan does.

### Requirements
KNXmap fork found at https://github.com/uwedisch/knxmap because of bug fixes that are currently not included in the original KNXmap.

python-shodan installed with <code>sudo apt-get python-shodan</code>.

csvtool installed with <code>sudo apt-get csvtool</code>.

Finally you also need an account with [Shodan](https://www.shodan.io).
  
### Execution
Called without any parameter csdig-knx searches on Shodan for the keyword <code>knx</code> and traverses thru all results.  Each result, i.e. KNXnet/IP (Tunneling) aware controller, is scanned for reachable KNX TP devices on it's configured KNX TP line.  Each reachable KNX TP device is also scanned.  Together all output is written to the directory <code>data</code>.

Use arguments '-h' or '--help' for help on how to work with <code>csdig-knx.sh</code>.

### Configuration
Configuration is done via file <code>csdig.conf</code>.

### Compatibility
Tested on Kali Linux 2020.1 Release and on Ubuntu 16.04 LTS. Tested in local environment against WAGO | Controller KNX IP (750-889), Viessmann Vitogate 200, type KNX and against knxd.

## Further Details of csdig
Please consult also the [wiki](https://github.com/uwedisch/csdig/wiki) for further details about csdig.
