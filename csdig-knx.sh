#!/bin/bash
#
#   csdig-knx - Control Systems Digger (KNX) digs into data found on Shodan.
#   Copyright (C) 2020  Uwe Disch
#
#   This program is free software: you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation, either version 3 of the License, or
#   (at your option) any later version.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program.  If not, see <https://www.gnu.org/licenses/>.
#
echo ""
echo "    csdig  Copyright (C) 2020  Uwe Disch"
echo "    This program comes with ABSOLUTELY NO WARRANTY; for details type 'show w'."
echo "    This is free software, and you are welcome to redistribute it"
echo "    under certain conditions; type 'show c' for details."
echo ""

#
# Source config file.
#
if [ -e ./csdig.conf ]
then
	. ./csdig.conf
fi
if [ -e /etc/csdig.conf ]
then
	. /etc/csdig.conf
fi
if [ -e ~/csdig.conf ]
then
	. ~/csdig.conf
fi

#
# Check for possible search string other than 'knx'.
#
if [ -n "$1" ]
then
	SEARCH="$1"
else
	SEARCH='knx'
fi

#
# If not debugging mode use current search results.
#
if [ -z "$DEBUG" ]
then
	$SHODAN download "$SEARCH" "$DATAPATH/$SEARCH"
	$SHODAN convert "$DATAPATH/$SEARCH.json.gz" csv
fi
HEIGHT=`$CSVTOOL height "$DATAPATH/$SEARCH.csv"`
$CSVTOOL namedcol data,ip_str,port,transport "$DATAPATH/$SEARCH.csv" > "$DATAPATH/$SEARCH-part.csv"
WIDTH=`$CSVTOOL width "$DATAPATH/$SEARCH-part.csv"`

#
# Loop thru search results.
#
for (( n=2; n<=$HEIGHT; n++ ))
do
	LINE=`$CSVTOOL sub $n 1 1 $WIDTH "$DATAPATH/$SEARCH-part.csv"`
	transport=${LINE##*,}
	port=${LINE%,*}
	ip_str=${port%,*}
	port=${port##*,}
	data=${ip_str%,*}
	ip_str=${ip_str##*,}
	
	#
	# If transport is udp, then check KNXnet/IP device.
	#
	if [ $transport = "udp" ]
	then
		#
		# Try to ping, if successful, the check KNXnet/IP device.
		#
		echo ""
#		TIMESTAMP=`date "+%Y-%m-%d %H:%M:%S"`
#		echo "$TIMESTAMP Checking if ping to $ip_str is successful"
#		RESULT=`ping -q -c 1 $ip_str|grep "0 received"`
#		if [ -n "$RESULT" ]
#		then
#			continue
#		fi
		TIMESTAMP=`date "+%Y-%m-%d %H:%M:%S"`
		echo "$TIMESTAMP Checking for KNXnet/IP controller on $ip_str:$port"
		RESULT=`$TIMEOUT --foreground $timeout nice -n -20 $KNXMAP -q -p $port --nat scan $ip_str 2>&1`
		
		#
		# Use KNX bus address to loop thru KNX line if KNX medium is
		# KNX TP.
		#
		medium=${RESULT##*KNX Medium: }
		# Keep care: newline at the end of the match string.
		medium=${medium%%
*}
		if [ "$medium" = "KNX TP" ]
		then
			address=${RESULT##*KNX Bus Address: }
			# Keep care: newline at the end of the match string.
			address=${address%%
*}
			#
			# Splice the address into it's parts.
			#
			group=${address%%.*}
			line=${address%.*}
			line=${line#*.}
#			device=${address##*.}
			#
			# Check all possible devices on that line.
			#
			device_start=0
			if [[ group -eq 0 ]] && [[ line -eq 0 ]]
			then
				device_start=1
			fi
			for (( m=$device_start; m<=255; m++ ))
			do
				TIMESTAMP=`date "+%Y-%m-%d %H:%M:%S"`
				echo "$TIMESTAMP Checking for KNX TP device on $group.$line.$m via KNXnet/IP controller on $ip_str:$port"
				# NAT mode is currently not working.  See:
				# <https://github.com/uwedisch/knxmap/issues/2>
				RESULT=`$TIMEOUT --foreground $timeout $KNXMAP -t -p $port --nat scan $ip_str $group.$line.$m --bus-info 2>&1`
				if [ -n "$DEBUG" ]
				then
					echo "---------- Debug start ----------"
					echo "$RESULT"
					echo "----------  Debug end  ----------"
					echo ""
				fi
				# Keep care: newline and 6 spaces at the end of
				# the match string.
				bus_device=${RESULT##*Bus Devices: 
      }
				# Keep care: newline at the end of the match
				# string.
				bus_device=${bus_device%%
*}
				if [ -n "$bus_device" ]
				then
					echo -e "\tKNX TP device $bus_device found"
				fi
			done
		fi
	fi
done
