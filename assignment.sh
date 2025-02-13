#!/bin/bash

BRIDGE_NAMES=('br0' 'br1')
NETNS_NAMES=("ns1" "ns2")
BRIDGE_IPS=("10.11.0.1/16" "10.12.0.1/16")
ROUTER_NETNS_NAME="router-ns"

# SETUP BRIDGE
for i in "${!BRIDGE_NAMES[@]}"; do
    br=${BRIDGE_NAMES[$i]}
    ip_addr=${BRIDGE_IPS[$i]}

    echo "Creating bridge: $br with IP: $ip_addr"

    sudo ip link add $br type bridge
    sudo ip link set $br up
    sudo ip addr add $ip_addr dev $br
done

sudo iptables -A FORWARD -o br0 -j ACCEPT
sudo iptables -A FORWARD -i br0 -j ACCEPT
sudo iptables -A FORWARD -i br1 -j ACCEPT
sudo iptables -A FORWARD -o br1 -j ACCEPT

echo "Bridges configured successfully!"


# SETUP NETNS
for i in "${!NETNS_NAMES[@]}";
do
        VETH_BRIDGE="veth_${NETNS_NAMES[i]}_b"
        VETH_NETNS="veth_${NETNS_NAMES[i]}_n"

        sudo ip netns add ${NETNS_NAMES[i]}
        
        sudo ip link add $VETH_NETNS type veth peer name $VETH_BRIDGE

        sudo ip link set $VETH_BRIDGE master ${BRIDGE_NAMES[i]}
        sudo ip link set $VETH_NETNS netns ${NETNS_NAMES[i]}

        sudo ip link set $VETH_BRIDGE up
        sudo ip netns exec ${NETNS_NAMES[i]} sudo ip link set $VETH_NETNS up

done

sudo ip netns exec ${NETNS_NAMES[0]} sudo ip addr add 10.11.0.11/24 dev "veth_${NETNS_NAMES[0]}_n"
sudo ip netns exec ${NETNS_NAMES[1]} sudo ip addr add 10.12.0.11/24 dev "veth_${NETNS_NAMES[1]}_n"


sudo ip netns add $ROUTER_NETNS_NAME

COMMON_CABLE_NAME="veth_br"

for i in "${!BRIDGE_NAMES[@]}"; 
do
        sudo ip link add ${COMMON_CABLE_NAME}$i type veth peer name veth_br${i}_router
        sudo ip link set ${COMMON_CABLE_NAME}$i master ${BRIDGE_NAMES[i]}
 
        sudo ip link set veth_br${i}_router netns $ROUTER_NETNS_NAME
        sudo ip link set ${COMMON_CABLE_NAME}$i up
        sudo ip netns exec $ROUTER_NETNS_NAME ip link set veth_br${i}_router up
done

sudo ip netns exec $ROUTER_NETNS_NAME sudo ip addr add 10.11.0.22/24 dev veth_br0_router
sudo ip netns exec $ROUTER_NETNS_NAME sudo ip addr add 10.12.0.22/24 dev veth_br1_router


sudo ip netns exec ${NETNS_NAMES[0]} ip route add 10.12.0.11 via 10.11.0.22
sudo ip netns exec ${NETNS_NAMES[1]} ip route add 10.11.0.11 via 10.12.0.22


show_menu() {
    echo "==========================="
    echo "  Network Namespace Menu"
    echo "==========================="
    echo "1. Ping from ns1 -> ns2"
    echo "2. Ping from ns2 -> ns1"
    echo "3. Show IP configurations"
    echo "4. Show routing table"
    echo "5. Exit"
    echo "==========================="
    echo -n "Enter your choice: "
}

ping_ns1_to_ns2() {
    echo "Pinging from ns1 to ns2..."
    sudo ip netns exec ${NETNS_NAMES[0]} ping -c 4 10.12.0.11
}

ping_ns2_to_ns1() {
    echo "Pinging from ns2 to ns1..."
    sudo ip netns exec ${NETNS_NAMES[1]} ping -c 4 10.11.0.11
}

show_ip_config() {
    for ns in "${NETNS_NAMES[@]}" "$ROUTER_NETNS_NAME"; do
        echo "IP Configuration for $ns:"
        sudo ip netns exec $ns ip addr show
        echo "--------------------------------"
    done
}

show_routing_table() {
    for ns in "${NETNS_NAMES[@]}" "$ROUTER_NETNS_NAME"; do
        echo "Routing Table for $ns:"
        sudo ip netns exec $ns ip route show
        echo "--------------------------------"
    done
}

clean_components(){
    for ns in "${BRIDGE_NAMES[@]}"; do
        echo "Deleting $ns"
        sudo ip link del $ns
    done

    for ns in "${NETNS_NAMES[@]}" "$ROUTER_NETNS_NAME"; do
        echo "Deleting $ns"
        sudo ip netns del $ns
    done

    echo "Exiting..."
}

while true; do
    show_menu
    read choice

    case $choice in
        1) ping_ns1_to_ns2 ;;
        2) ping_ns2_to_ns1 ;;
        3) show_ip_config ;;
        4) show_routing_table ;;
        5) clean_components && exit 0 ;;
        *) echo "Invalid choice, please try again." ;;
    esac

    echo ""
done

