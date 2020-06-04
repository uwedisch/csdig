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
# Check for possible search string other than 'knx'.
#
if [ -n "$1" ]
then
	SEARCH="$1"
else
	SEARCH='knx'
fi

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
cd "$KNXMAPPATH"

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
# Create new device list and add the header to the it.
#
echo "Timestamp;Controller;Devices" > "$DEVICELIST"

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
		echo ""
		TIMESTAMP=`date "+%Y-%m-%d %H:%M:%S"`
		echo "$TIMESTAMP Checking for KNXnet/IP controller on $ip_str:$port"
		RESULT=`$TIMEOUT --foreground $timeout $KNXMAP -q -p $port --nat scan $ip_str 2>&1`
		
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
			#
			# Write the controller output to specific text file.
			#
			echo -n "$ip_str:$port $RESULT" > "$DATAPATH/$SEARCH.$ip_str.$port.txt"
			TIMESTAMP=`date "+%Y-%m-%d %H:%M:%S"`
			echo -n "$TIMESTAMP Found a KNXnet/IP controller on $ip_str:$port, checking for KNX TP devices"
			if [ $DEBUG -ge 5 ]
			then
				echo ""
			fi
			#
			# Add controller to the device list.
			#
			echo -n "$TIMESTAMP;$ip_str:$port;" >> "$DEVICELIST"
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
				if [ $DEBUG -ge 5 ]
				then
					TIMESTAMP=`date "+%Y-%m-%d %H:%M:%S"`
					echo "$TIMESTAMP Checking for KNX TP device on $group.$line.$m via KNXnet/IP controller on $ip_str:$port"
				else
					if [ $m -eq 255 ]
					then
						echo ".  Done."
					else
						echo -n "."
					fi
				fi
				# Also retrieve the bus-info on each device.
				# But, state machine isn't perfect.  See:
				# <https://github.com/uwedisch/knxmap/issues/2>
				RESULT=`$TIMEOUT --foreground $timeout $KNXMAP -q -p $port --nat scan $ip_str $group.$line.$m --bus-info 2>&1`
				if [ $DEBUG -ge 9 ]
				then
					echo "---------- Debug start ----------"
					echo "$RESULT"
					echo "----------  Debug end  ----------"
					echo ""
				fi
				# Check if there was a connection time out in
				# tunnel.  If so, log this event.
				ConnectionTimeout=`echo "$RESULT"|grep 'Tunnel connection timed out'`
				if [ -n "$ConnectionTimeout" ]
				then
					if [ $DEBUG -ge 1 ]
					then
						TIMESTAMP=`date "+%Y-%m-%d %H:%M:%S"`
						echo -e "\n$TIMESTAMP Tunnel connection timed out at KNXnet/IP controller on $ip_str:$port after round $m"
					fi
				fi
				# Check if there was a unexpected diconnect
				# request.  If so, log this event also.
				DisconnectRequest=`echo "$RESULT"|grep 'Received unexpected tunnel disconnect request'`
				if [ -n "$DisconnectRequest" ]
				then
					if [ $DEBUG -ge 1 ]
					then
						TIMESTAMP=`date "+%Y-%m-%d %H:%M:%S"`
						echo -e "\n$TIMESTAMP Unexpected tunnel disconnect request received from KNXnet/IP controller on $ip_str:$port while scanning target device $group.$line.$m"
					fi
				fi
				# Keep care: newline and 6 spaces at the end of
				# the match string.
				bus_device=${RESULT##*Bus Devices: 
      }
				CONTENT=`echo -n "$bus_device"`
				# Keep care: newline at the end of the match
				# string.
				bus_device=${bus_device%%
*}
				bus_device=${bus_device%%:*}
				if [ -n "$bus_device" ]
				then
					if [ $DEBUG -ge 5 ] || [ -z "$DEBUG" ]
					then
						echo -e "\tKNX TP device $bus_device found"
					else
						if [ $DEBUG -ge 1 ]
						then
							echo -n " $bus_device "
						fi
					fi
					#
					# Add device to the device list.
					#
					echo -n "$bus_device," >> "$DEVICELIST"
					#
					# Write the device output to specific
					# text file.
					#
					echo -n "$ip_str:$port $CONTENT" > "$DATAPATH/$SEARCH.$ip_str.$port.$bus_device.txt"
				fi
				#
                                # Output additional line break to
                                # device list on last round.
                                #
				if [ $m -eq 255 ]
				then
					echo "" >> "$DEVICELIST"
				fi
			done
		fi
	fi
done
