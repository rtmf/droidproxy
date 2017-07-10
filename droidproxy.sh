#!/usr/bin/zsh
# vim: syntax=zsh ts=2 sw=2 noexpandtab
#
MODULE="droidproxy"
PREFIX="/opt/droidproxy"
DOMAIN="$(hostname -d)"
HOSTID="$(hostname -s)"
CACERT="${PREFIX}/${DOMAIN}.pem"
MYCERT="${PREFIX}/${HOSTID}.${DOMAIN}.crt"
SECRET="${PREFIX}/${HOSTID}.${DOMAIN}.pem"
THISIS="${PREFIX}/${MODULE}.sh"
REMOTE="74.207.244.165"
REPORT="1057"
ANPORT="8008"
LOPORT="8483"
TUNTYP="droidproxy" 
DNSSRV="${REMOTE}"
DNSDOM="${DOMAIN}"
SEARCH="tesayon.xh cccn.xh xh"
VPNPID="${PREFIX}/openvpn.pid"
TUNPID="${PREFIX}/proxy.pid"
SVCPID="${PREFIX}/droidproxy.sh.pid"
DAEMON={VPN,TUN,SVC}PID
ANPATH="/data/local/tmp"
RESOLV=$(<<-__RESOLV__
# resolv.conf, written by ${MODULE}
nameserver ${DNSSRV}
domain ${DOMAIN}
search ${DOMAIN} ${SEARCH}
__RESOLV__
)
case "${TUNTYP}" in
	ssh)
		SAPORT="7175"
		SLPORT="2816"
		BINARY="sshd"
		TERMUX="/data/data/com.termux/files"
		SSHDIS="${TERMUX}/usr/bin/${BINARY}"
		SSHDLD="${TERMUX}/usr/lib"
		SSHDPK="${PREFIX}/authorized_keys"
		SSHDKF="${ANPATH}/authorized_keys"
		SSHDCF="${ANPATH}/sshd_config"
		SSHDOP="$(<<- __SSHD_CONFIG__
										PasswordAuthentication			no
										PubkeyAcceptedKeyTypes			ssh-rsa
										Port												${SAPORT}
										AuthorizedKeysFile					${SSHDKF}
										StrictModes									no
									__SSHD_CONFIG__
								)"
		SSHDGO="$(<<- __SSHD_STARTUP_SCRIPT__
										#!/system/bin/sh
										busybox killall -9 sshd
										busybox chown \$(id -u):\$(id -g) ${SSHDKF} ${SSHDCF}
										busybox chmod 0644 ${SSHDKF} ${SSHDCF}
										export LD_LIBRARY_PATH=${SSHDLD}:\${LD_LIBRARY_PATH}
										export PATH=${TERMUX}/usr/bin:${TERMUX}/usr/bin/applets:\${PATH}
										${SSHDIS} -f ${SSHDCF} -p ${SAPORT}
									__SSHD_STARTUP_SCRIPT__
								)"
								cat =(<<<"$SSHDGO")
		SSHDSF="${ANPATH}/sshd.sh"
		;;
	droidproxy|dproxy|dp|droid|proxy)
		BINARY="proxy"
		DPROXY="${PREFIX}/${BINARY}"
		APROXY="${ANPATH}/${BINARY}"
		;;
esac

eval "${PIDINF}"
ACTION="${1:-help}"
case "${ACTION}" in
	kill)
		killall -9 openvpn
		for RUNNER in $DAEMON
		do
			PFNAME="${(P)RUNNER}"
			RUNPID="${$(<${PFNAME}):-0}" 2>/dev/null
			(( ${RUNPID} )) && kill -9 ${RUNPID} 
			rm -f ${PFNAME}
		done
		;;
	stop)
		[ -f ${SVCPID} ] && kill -SIGINT "$(<${SVCPID})"
		exit 0
		#this should be enough to get the internal teardown to happen
		;;
	start)
		zsh "${THISIS}" kill
		zsh "${THISIS}" fork &
		echo "$!" > "${SVCPID}"
		disown
		;;
	fork)
		adb kill-server
		rm -f /etc/resolv.conf
		echo "${RESOLV}" > /etc/resolv.conf
		(
		adb shell "busybox killall -9 ${BINARY}"
		case ${TUNTYP} in
			droidproxy|dproxy|dp|droid|proxy)
				adb forward tcp:${LOPORT} tcp:${ANPORT}
				chmod 0755 ${DPROXY}
				adb push ${DPROXY} ${APROXY}
				(
				adb shell "${APROXY} ${ANPORT} ${REMOTE} ${REPORT} " 
				)&
				;;
			ssh)
				ssh-keygen -R localhost
				SSHTMP="$(mktemp -d -t droidproxy-ssh-tunnel-XXXX)"
				[ -d "${SSHTMP}" ] || exit 255
				ssh-keygen -t rsa -b 1024 -N "" -C "DroidProxy" -f ${SSHTMP}/key
				SSHPUB="${SSHTMP}/key.pub"
				SSHPRI="${SSHTMP}/key"
				SSHDAK="$(<<- __SSHD_AUTHORIZED_KEYS__
												$(<${SSHPUB})
												${$(<${SSHDPK}):-}
												$(ssh-add -L)
											__SSHD_AUTHORIZED_KEYS__
				)$" 2>/dev/null
				echo "${SSHDAK}"
				echo "${SSHDOP}"
				adb push =(<<<${SSHDAK}) ${SSHDKF}
				adb push =(<<<${SSHDOP}) ${SSHDCF}
				adb forward tcp:${SLPORT} tcp:${SAPORT}
				adb push =(<<<${SSHDGO}) ${SSHDSF}
				adb shell "/system/xbin/busybox chmod 0755 ${SSHDSF}"
				adb shell "su -c ${SSHDSF}" 
				ssh-keyscan -vvv -p ${SLPORT} localhost | tee -a ${HOME}/.ssh/known_hosts
				ssh -oStrictHostKeyChecking=no -oCheckHostIP=no -N -oIdentityFile=${SSHPRI} -oIdentitiesOnly=yes -oIdentityAgent=none -oNoHostAuthenticationForLocalhost=yes -oPasswordAuthentication=no -oPreferredAuthentications=publickey -oPort=${SLPORT} -T -L ${LOPORT}:${REMOTE}:${REPORT} droidproxy@localhost & 
				;;
		esac
		echo "$!" > ${TUNPID}
		trap "kill -SIGINT $(<${TUNPID})" SIGINT
		wait "$(<${TUNPID})"
		case "${TUNTYP}" in
			ssh)
				rm -rf "${SSHTMP}/"
				;;
		esac
		rm -f "${TUNPID}" ) & TUNSVR="$!"
		(
		pkill -9 openvpn
		openvpn --client \
			--remote localhost ${LOPORT} \
			--proto tcp-client\
			--ca ${CACERT} \
			--key ${SECRET} \
			--cert ${MYCERT} \
			--comp-lzo yes \
			--dev tun \
			--persist-tun \
			--persist-key \
			--verb 3 \
			--script-security 2 \
			--tls-client \
			--route 0.0.0.0 0.0.0.0 vpn_gateway \
			--sndbuf 1 \
			--rcvbuf 1 \
			--socket-flags TCP_NODELAY \
			--pull &
		echo "$!" > ${VPNPID}
		trap "kill -SIGINT $(<${VPNPID})" SIGINT
		wait "$(<${VPNPID})"
		rm -f "${VPNPID}" ) & VPNSVR="$!"
		cleanup() {
			[ -f ${VPNPID} ] && kill -SIGINT "$(<${VPNPID})"
			[ -f ${TUNPID} ] && kill -SIGINT "$(<${TUNPID})"
		}
		trap "cleanup" SIGINT
		wait "$TUNSVR" "$VPNSVR"
		cleanup
		wait "$TUNSVR" 
		wait "$VPNSVR"
		adb kill-server
		rm -f "${SVCPID}"
		exit 0
		;;
	restart)
		zsh "${THISIS}" stop
		zsh "${THISIS}" start
		;;
	help)
		echo "I ran out of time."
		;;
esac
