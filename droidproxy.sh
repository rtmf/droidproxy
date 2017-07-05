#!/usr/bin/zsh
PREFIX="/opt/droidproxy"
REMOTE="74.207.244.165"
REPORT="8080"
ANPORT="5050"
LOPORT="5050"
BINARY="proxy"
ANPATH="/data/local/tmp"
DPROXY="${PREFIX}/${BINARY}"
APROXY="${ANPATH}/${BINARY}"
DOMAIN="$(dnsdomainname)"
HOSTID="$(hostname -s)"
adb kill-server
rm -f /etc/resolv.conf
cat > /etc/resolv.conf <<- __RESOLV_CONF__
#resolv.conf, written by droidproxy
nameserver 74.207.244.165
domain ${DOMAIN}
search ${DOMAIN} tesayon.xh cccn.xh xh
__RESOLV_CONF__
chmod 0755 ${DPROXY}
adb push ${DPROXY} ${APROXY}
adb shell "busybox killall -9 proxy"
adb shell "${APROXY} ${ANPORT} ${REMOTE} ${REPORT} " &
adb forward tcp:${LOPORT} tcp:${ANPORT}
openvpn --config ${PREFIX}/${HOSTID}.${DOMAIN}.conf --remote 127.0.0.1 ${LOPORT}
adb kill-server
kill -9 %1
