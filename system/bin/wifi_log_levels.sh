#!/system/bin/sh
## Copyright (c) 2017 - 2023 Amazon.com, Inc. or its affiliates.  All rights reserved.
##
## PROPRIETARY/CONFIDENTIAL.  USE IS SUBJECT TO LICENSE TERMS.

LOGSRC="wifi"
LOGNAME="wifi_log_levels"
DELAY=120
LOOPSTILMETRICS=29 # Should send to metrics buffer every hour
LOOPSTILTEMP=7 # Send temperature reading to buffer every 14 min
currentLoop=0
WL=/system/xbin/wl
TOOLBOX=/system/bin/toolbox

source /system/bin/wifi_metrics_common.sh

if [[ ! -x $WL || ! -x $TOOLBOX ]] ; then
	exit
fi

function log_wifi_logcat
{
	RSSI=`$WL -i $WLAN_IFACE rssi`
	NOISE=`$WL -i $WLAN_IFACE noise`

	CHANNEL=`$WL -i $WLAN_IFACE chanspec`
	CHANNEL=${CHANNEL% *}
	CHANNEL=${CHANNEL%/*}	#in case of channel # followed by a /
	CHANNEL=${CHANNEL%l*}	#in case of channel # followed by a l for lower channel
	CHANNEL=${CHANNEL%u*}	#in case of channel # followed by a u for upper channel
	BTC27=`$WL btc_params 27`

	if [ "$RSSI" -eq 0 ]; then
		CONN_STATUS="ConnStatusDisconnected"
	else
		CONN_STATUS="ConnStatusConnected"
		if [[ "$RSSI" -lt "${RSSITHD[0]}" ]]; then
			RSSIBAR=0
		elif [[ "$RSSI" -lt "${RSSITHD[1]}" ]]; then
			RSSIBAR=1
		elif [[ "$RSSI" -lt "${RSSITHD[2]}" ]]; then
			RSSIBAR=2
		elif [[ "$RSSI" -lt "${RSSITHD[3]}" ]]; then
			RSSIBAR=3
		elif [[ "$RSSI" -lt "-40" ]]; then
			RSSIBAR=4
		elif [[ "$RSSI" -lt "-20" ]]; then
			RSSIBAR=5
		else
			RSSIBAR=6
		fi

		if [[ "$NOISE" -lt "${RSSITHD[0]}" ]]; then
			NOISEBAR=0
		elif [[ "$NOISE" -lt "${RSSITHD[1]}" ]]; then
			NOISEBAR=1
		elif [[ "$NOISE" -lt "${RSSITHD[2]}" ]]; then
			NOISEBAR=2
		elif [[ "$NOISE" -lt "${RSSITHD[3]}" ]]; then
			NOISEBAR=3
		elif [[ "$NOISE" -lt "-40" ]]; then
			NOISEBAR=4
		elif [[ "$NOISE" -lt "-20" ]]; then
			NOISEBAR=5
		else
			NOISEBAR=6
		fi


	fi

	logStr="rssi=$RSSI;noise=$NOISE;channel=$CHANNEL;btcparam27=$BTC27;"

	COUNTERS=($($WL counters))
	i=0
	while [[ $i -lt $((${#COUNTERS[*]} - 1)) ]] ; do
		case ${COUNTERS[$i]} in txframe|txbyte|txretrans|txerror|rxframe|rxbyte|rxerror|txburst|txphyerror|rxbadplcp|rxcrsglitch|rxstrt|rxdfrmucastmbss|rxbadfcs)
			logStr=$logStr"${COUNTERS[$i]}=${COUNTERS[$i+1]};"
			;;
		esac
		((i++))
	done

	log -t $LOGNAME $logStr

	TEMP=($($WL phy_tempsense))
	TEMP=${TEMP[0]} # print first field decimal only (other field is hex)
	logStr="phy_tempsense=$TEMP;"
	log -t $LOGNAME $logStr

	log_chanim_logcat

	log_rates_logcat
}

function log_chanim_logcat
{
	# Add wl chanim stats output (configurable option in FW)
	IMCOUNTERS=($($WL chanim_stats))
	if [ $IMCOUNTERS != "failed" ] ; then
		logStr=""
		j=2
		while [[ $j -lt $((${#IMCOUNTERS[*]} - $CHANIM_NUM_STATS)) ]] ; do
			case ${IMCOUNTERS[$j]} in chanspec|tx|inbss|obss|nocat|nopkt|doze|txop|goodtx|badtx|ed|glitch|badplcp|knoise|idle)
				logStr=$logStr"${IMCOUNTERS[$j]}=${IMCOUNTERS[$j+$CHANIM_NUM_STATS]};"
				# update congestion property
				if [[ ${IMCOUNTERS[$j]} == "txop" ]]; then
					setprop 'wifi.ro.wlan0.congest' $(( 100 - ${IMCOUNTERS[$j+$CHANIM_NUM_STATS]} ))
				fi
				;;
			esac
			((j++))
		done

		log -t $LOGNAME $logStr
	fi
}

function log_nrate_logcat
{
	typeset logStr="${1}: " # nrate or rx_nrate
	shift
	typeset str=$@ # parameter string
	str=($str)

	typeset IFS="_"

	if [[ "${str[0]}" == "auto" ]]; then
		logStr=$logStr"auto"
	elif [[ "${str[0]}" == "legacy" ]]; then
		logStr=$logStr"legacy_rate=${str[2]};stf_mode=${str[6]};"
		shift 7
		logStr=$logStr"rspec_auto=$*;"
	elif [[ "${str[0]}" == "mcs" ]]; then
		logStr=$logStr"mcs_index=${str[2]};stf_mode=${str[5]};"
		shift 6
		logStr=$logStr"rspec_auto=$*;"
	elif [[ "${str[0]}" == "vht" ]]; then
		logStr=$logStr"vht_mcs=${str[2]};Nss=${str[4]};"
		logStr=$logStr"${str[5]}_Exp=${str[7]};" # tx or rx

		typeset i=8
		if [[ "${str[8]}" == "bw"* ]]; then
			logStr=$logStr"bw=${str[8]};" # bandwidth
			i=9
		fi

		typeset paramNames # list all possible variable parameters
		paramNames=( "stbc" "txbf" "ldpc" "sgi" )

		typeset paramVals # matching param values, initialized to 0
		for k in ${paramNames[*]}; do paramVals+=(0); done

		while [[ $i -lt ${#str[*]} ]]; do
			typeset tmpStr=${str[$i]}
			typeset j=0
			while [[ $j -lt ${#paramNames[*]} ]]; do
				if [[ "${paramNames[$j]}" == "$tmpStr" ]]; then
					paramVals[$j]=1 # param exists = on
					break
				fi
				((j++))
			done
			if [[ "$tmpStr" == "auto" ]] || [[ "$tmpStr" == "fixed" ]]; then
				shift $i # found last param rspec_auto
				break
			fi
			((i++))
		done
		for k in ${!paramNames[*]}; do
			# print all parameters 0=off, 1=on
			logStr=$logStr"${paramNames[$k]}=${paramVals[$k]};"
		done
		logStr=$logStr"rspec_auto=$*;"
	elif [[ ${str[0]} == "Rx" ]]; then
		logStr=$logStr"$*;" # Rx Rate setting not allowed
	fi

	unset IFS
	log -t $LOGNAME "${logStr}"
}

get_phyrate_str() {
    local ratembps=$1
    local mcsbwinfo=$2

    case $mcsbwinfo in
        mcs*)
            local mcs=$(echo $mcsbwinfo | cut -d ' ' -f3)
            # for ht case there is no bandwidth available above, infer from
            # actual phy rate in mbps
            local phyrate=$ratembps
            case $phyrate in
                13\.5 | 27| 40\.5|54|81|108|121\.5| 135) local bw=40 ;;
                15 | 30|45|60|90|120|135| [1-2][5-9][0-9] | 300) local bw=40 ;;
                *) local bw=20 ;;
            esac
            local ratestr="MCS${mcs}_BW${bw}"
            ;;
        vht*)
            local mcs=$(echo $mcsbwinfo | cut -d ' ' -f3)
            local nss=$(echo $mcsbwinfo | cut -d ' ' -f5)
            local bwstr=$(echo $mcsbwinfo | cut -d ' ' -f9)
            local bw=${bwstr##bw}
            local ratestr="NSS${nss}_MCS${mcs}_BW${bw}"
            ;;
        legacy*)
            local rate=$(echo $mcsbwinfo | cut -d ' ' -f3)
            local ratestr="${rate}M_BW20"
            ;;
    esac

    echo $ratestr
}

function log_rates_logcat
{
	# Add wl rate/nrate/rx_rate/rx_nrate output
	wl_rate=($($WL rate))
	logStr="rate=${wl_rate[0]};" # remove Mbps from field

	wl_rx_rate=($($WL rx_rate))
	logStr=$logStr"rx_rate=${wl_rx_rate[0]};"

	log -t $LOGNAME $logStr

	wl_nrate=$($WL nrate)
	tx_mcs_str=$wl_nrate
	wl_nrate="nrate $wl_nrate"
	log_nrate_logcat $wl_nrate

	wl_rx_nrate=$($WL rx_nrate)
	rx_mcs_str=$wl_rx_nrate
	wl_rx_nrate="rx_nrate $wl_rx_nrate"
	log_nrate_logcat $wl_rx_nrate

	#store the tx/rx phy rate
	LASTRXRATE=$(get_phyrate_str "${wl_rx_rate[0]}" "${rx_mcs_str}")
	LASTTXRATE=$(get_phyrate_str "${wl_rate[0]}" "${tx_mcs_str}")
}

function log_maxmin_wifi
{
	if [[ ! "$MAX_RSSI" && ! "$MIN_RSSI" && ! "$RSSI" -eq 0 ]] ; then
		MAX_RSSI=$RSSI
		MIN_RSSI=$RSSI
	fi

	if [[ ! "$MAX_NOISE" && ! "$MIN_NOISE" && ! "$NOISE" -eq 0 ]] ; then
		MAX_NOISE=$NOISE
		MIN_NOISE=$NOISE
	fi

	if [ ! $RSSI -eq 0 ] ; then
		if [ $RSSI -gt $MAX_RSSI ] ; then
			MAX_RSSI=$RSSI
		fi

		if [ $RSSI -lt $MIN_RSSI ] ; then
			MIN_RSSI=$RSSI
		fi
	fi

	if [ ! $NOISE -eq 0 ] ; then
		if [ $NOISE -gt $MAX_NOISE ] ; then
			MAX_NOISE=$NOISE
		fi

		if [ $NOISE -lt $MIN_NOISE ] ; then
			MIN_NOISE=$NOISE
		fi
	fi

	logStr="max_rssi=$MAX_RSSI;min_rssi=$MIN_RSSI;max_noise=$MAX_NOISE;min_noise=$MIN_NOISE;"
	log -t $LOGNAME $logStr
}

function log_maxmin_p2p
{
	if [[ ! "$MAX_P2P_RSSI" && ! "$MIN_P2P_RSSI" && ! "$P2P_RSSI" -eq 0 ]] ; then
		MAX_P2P_RSSI=$P2P_RSSI
		MIN_P2P_RSSI=$P2P_RSSI
	fi

	if [[ ! "$MAX_P2P_NOISE" && ! "$MIN_P2P_NOISE" && ! "$P2P_NOISE" -eq 0 ]] ; then
		MAX_P2P_NOISE=$P2P_NOISE
		MIN_P2P_NOISE=$P2P_NOISE
	fi

	if [ ! $P2P_RSSI -eq 0 ] ; then
		for p2pRssi in ${P2P_RSSI_LIST[@]}; do
			if [ $p2pRssi -eq 0 ] ; then
				continue
			fi

			if [ $p2pRssi -gt $MAX_P2P_RSSI ] ; then
				MAX_P2P_RSSI=$p2pRssi
			fi

			if [ $p2pRssi -lt $MIN_P2P_RSSI ] ; then
				MIN_P2P_RSSI=$p2pRssi
			fi
		done
	fi

	if [ ! $P2P_NOISE -eq 0 ] ; then
		if [ $P2P_NOISE -gt $MAX_P2P_NOISE ] ; then
			MAX_P2P_NOISE=$P2P_NOISE
		fi

		if [ $P2P_NOISE -lt $MIN_P2P_NOISE ] ; then
			MIN_P2P_NOISE=$P2P_NOISE
		fi
	fi

	logStr="max_p2prssi=$MAX_P2P_RSSI;min_p2prssi=$MIN_P2P_RSSI;max_p2pnoise=$MAX_P2P_NOISE;min_p2pnoise=$MIN_P2P_NOISE"
	log -t $LOGNAME $logStr
}

# Log the maximum and minimum values regarding signal quality
function log_maxmin_signals_logcat
{
	if [[ ! "$PREVIOUS_CHANNEL" ]] ; then
		PREVIOUS_CHANNEL=$CHANNEL
	elif [[ $PREVIOUS_CHANNEL != $CHANNEL ]] ; then
		PREVIOUS_CHANNEL=$CHANNEL
		MAX_RSSI=''
		MIN_RSSI=''
		MAX_NOISE=''
		MIN_NOISE=''
		MAX_P2P_RSSI=''
		MIN_P2P_RSSI=''
		MAX_P2P_NOISE=''
		MIN_P2P_NOISE=''
	fi

	log_maxmin_wifi

	if [ "$P2P_IFACE" ] ; then
		log_maxmin_p2p
	fi
}

function log_p2p_logcat ()
{
	P2P_CLIENT_LIST=$($WL -i $P2P_IFACE assoclist)

	logStr=""
	if [ "$P2P_CLIENT_LIST" ] ; then
		index=0
		REST_OF_LIST=${P2P_CLIENT_LIST#*assoclist?}

		while [ "$REST_OF_LIST" ] ; do
			P2P_MAC_ADDR=${REST_OF_LIST%%?assoclist*}
			P2P_RSSI=$($WL -i $P2P_IFACE rssi $P2P_MAC_ADDR)

			if [ $P2P_RSSI -ne 0 ] ; then
				P2P_RSSI_LIST[$index]=$P2P_RSSI
				((index++))
				logStr=$logStr"p2p_dev_address="$P2P_MAC_ADDR" p2prssi="$P2P_RSSI";"
			fi

			REST_OF_LIST=${REST_OF_LIST#*$P2P_MAC_ADDR}
			REST_OF_LIST=${REST_OF_LIST#*assoclist?}
		done
	fi

	P2P_NOISE=`$WL -i $P2P_IFACE noise`
	logStr=$logStr"p2pnoise=$P2P_NOISE;"

	log -t $LOGNAME $logStr
}

function log_kdm_band
{
	if [ "$CONN_STATUS" == "ConnStatusDisconnected" ]; then
		return 0
	fi

	#get band
	if [[ $CHANNEL -lt 36 ]] ; then
		BAND="2G"
		if [ "$CHANNEL" -eq 1 -o "$CHANNEL" -eq 6 -o "$CHANNEL" -eq 11 ] ; then
			CHGROUP="2G_prime"
		elif [[ $CHANNEL -gt 11 ]] ; then
			CHGROUP="2G_high"
		else
			CHGROUP="2G_non_prime"
		fi
	elif [[ $CHANNEL -gt 35 ]] ; then
		BAND="5G"
		if [[ $CHANNEL -lt 49 ]] ; then
			CHGROUP="5G_UNII1"
		elif [[ $CHANNEL -lt 145 ]] ; then
			CHGROUP="5G_UNII2"
		else
			CHGROUP="5G_UNII3"
		fi
	else
		BAND="error"
		CHGROUP="error"
		return 0
	fi


	#get bandwidth
	if [ ! "$bandwidth" ] ; then
		# Device is 11a/b/g which only has 20 MHz bandwidth
		bandwidth="20MHz"
	fi

	if [ ! "$wifimode" ] ; then

		# wl status should have "VHT Capable:" or "HT Capable:" for 11n/ac
		ht=`echo "$status" | grep "HT Capable"`
		if [ "$ht" ] ; then
			# Some 2.4 GHz connections display VHT Capable. Check channel.
			if [[ "$ht" == "HT Capable:" ]] ; then
				wifimode="11n"
			else
				wifimode="11ac"
			fi
		else
			# If all the supported rates have (b), assume 11b.
			rates=`echo "$status" | grep "Supported Rates"`
			case $rates in
				*6*|*9*|*[1-5][2-8]*)
				# If any OFDM rate is present check for the channel
					if [ $channel -lt 36 ] ; then
						wifimode="11g"
					else
						wifimode="11a"
					fi
					;;
				*)
					# No OFDM rate present
					wifimode='11b'
					;;
			esac

		fi
	fi
	log_to_kdm_minerva "operation=Band;key=${CHGROUP};metadata=${bandwidth};metadata1=${wifimode}"
}

function log_kdm_rssi_level
{
	if [ "$CONN_STATUS" == "ConnStatusDisconnected" ]; then
		return 0
	fi
	log_to_kdm_minerva "operation=RSSILevel;key=${BAND};metadata=${RSSIBAR} bar"
}

function log_kdm_noise_level
{
	if [ "$CONN_STATUS" == "ConnStatusDisconnected" ]; then
		return 0
	fi
	log_to_kdm_minerva "operation=NoiseLevel;key=${BAND};metadata=${NOISEBAR} bar"
}

function log_kdm_snr_level
{
	if [ "$RSSI" -eq 0 -o "$NOISE" -eq 0 -o "$CONN_STATUS" == "ConnStatusDisconnected" ]; then
		return 0
	fi

	SNR=$(($RSSI - $NOISE))

	if [[ "$SNR" -lt "5" ]]; then
		SNRBAR=0
	elif [[ "$SNR" -lt "10" ]]; then
		SNRBAR=1
	elif [[ "$SNR" -lt "15" ]]; then
		SNRBAR=2
	elif [[ "$SNR" -lt "20" ]]; then
		SNRBAR=3
	elif [[ "$SNR" -lt "25" ]]; then
		SNRBAR=4
	elif [[ "$SNR" -lt "30" ]]; then
		SNRBAR=5
	else
		SNRBAR=6
	fi
	log_to_kdm_minerva "operation=SNRLevel;key=${BAND};metadata=${SNRBAR} bar;metadata1=${RSSIBAR} bar;metadata2=${LASTTXRATE}"
}

function log_kdm_phyrate
{
	# skip if not connected
	if [ -z "$RSSI" ] ; then
		return 0
	fi

	if [ -n "$LASTTXRATE" ] ; then
		log_to_kdm_minerva "operation=PhyRate;key=Tx;metadata=${LASTTXRATE};metadata1=${RSSIBAR} bar;metadata2=${SNRBAR} bar;metadata3=${wifimode}"
	fi

	if [ -n "$LASTRXRATE" ] ; then
		log_to_kdm_minerva "operation=PhyRate;key=Rx;metadata=${LASTRXRATE};metadata1=${RSSIBAR} bar;metadata2=${SNRBAR} bar;metadata3=${wifimode}"
	fi
}

function log_kdm_txop
{
	if [ $CONN_STATUS != "ConnStatusConnected" ] ; then
		return
	fi

	CHANCOUNTERS=($($WL -i $WLAN_IFACE chanim_stats))
	if [ $CHANCOUNTERS != "failed" ] ; then
		k=3 # skip version # and chanspec from "wl chanim_stats" output
		while [[ $k -lt $((${#CHANCOUNTERS[*]} - $CHANIM_NUM_STATS)) ]] ; do
			case ${CHANCOUNTERS[$k]} in txop)
				# specify txop in 2g or 5g
				if [[(${CHANCOUNTERS[$k+$CHANIM_NUM_STATS]} -lt 100) && (${CHANCOUNTERS[$k+$CHANIM_NUM_STATS]} -gt 1)]] ; then
					TXOP=${CHANCOUNTERS[$k+$CHANIM_NUM_STATS]}
					TXOP_BUCKETS=$(($TXOP / 10))
				else
					return
				fi
				;;
			esac
			((k++))
		done
	else
		return
	fi

	HPD=$(cat /sys/class/switch/hdmi/state)
	HDCP=$(cat /sys/class/switch/hdcp/state)

	if [[ "$HPD" == 1 && "$HDCP" == 1 ]] ; then
		TVSTATE="ON"
	else
		TVSTATE="OFF"
	fi
	log_to_kdm_minerva "operation=Txop;key=${BAND};metadata=${TXOP_BUCKETS};metadata1=${TVSTATE}"
}

function log_wifi_metrics
{
	log_kdm_band
	log_kdm_rssi_level
	log_kdm_noise_level
	log_kdm_snr_level
	log_kdm_txop
	log_kdm_phyrate
}

function clear_stale_stats
{
	NOISE=0
	RSSI=0
	P2P_RSSI=0
	P2P_NOISE=0
	CHANNEL=0
	unset P2P_RSSI_LIST
	$WL reset_cnts
}

function run ()
{
	WLAN_IFACE=`getprop wifi.interface`
	P2P_IFACE=`getprop wlan.interface.p2p.group`
	RSSI_THRESHOLDS=`getprop persist.wifi.rssi.thresholds`
	typeset IFS=","
	i=0
	for thd in $RSSI_THRESHOLDS; do
		RSSITHD[i++]=$thd
	done
	unset IFS
	CHANIM_NUM_STATS=16
	log_wifi_logcat

	if [ "$P2P_IFACE" ] ; then
		log_p2p_logcat
	fi

	log_maxmin_signals_logcat

	if [[ $currentLoop -ne 0 && $(($currentLoop % $LOOPSTILTEMP)) -eq 0 ]] ; then
		log_metrics_temp
	fi

	if [[ $currentLoop -eq $LOOPSTILMETRICS ]] ; then
		log_wifi_metrics

		if [ "$P2P_IFACE" ] ; then
			log_p2p_metrics
		fi
		currentLoop=0
	else
		((currentLoop++))
	fi

	clear_stale_stats
}

# Run the collection repeatedly, pushing all output through to the metrics log.
while true ; do
	run
	sleep $DELAY
done
