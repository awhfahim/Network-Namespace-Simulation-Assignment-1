### **Setting Up a FIB Network with Two Namespaces (NS1 & NS2) and a Router Namespace**

You want to create a **Forwarding Information Base (FIB)** network where:

- `ns1` and `ns2` are **two separate network namespaces**.
- They are connected to **different bridges**.
- A **router namespace** will route packets between them.

---

The IP addressing scheme follows a **subnet-based segmentation**:

- **Bridge br0**: `10.11.0.0/24` (Subnet for ns1)
- **Bridge br1**: `10.12.0.0/24` (Subnet for ns2)
- **Router Namespace (router-ns)** acts as the gateway:
    - `10.11.0.22` for `ns1`
    - `10.12.0.22` for `ns2`

### **🛠 Network Plan**

| Namespace | Interface | IP Address | Connected To |
| --- | --- | --- | --- |
| `ns1` | `veth_ns1_n` | `10.11.0.11/24` | `br0` |
| `ns2` | `veth_ns2_n` | `10.12.0.11/24` | `br1` |
| `router-ns` | `veth_br0_router` | `10.11.0.22/24` | `br0` |
| `router-ns` | `veth_br1_router` | `10.12.0.22/24` | `br1` |

---

### **1️⃣ Create Network Namespaces**

```bash
ip netns add ns1
ip netns add ns2
ip netns add router-ns

```

---

### **2️⃣ Create Bridges**

```bash
ip link add br0 type bridge
ip link add br1 type bridge
ip link set br0 up
ip link set br1 up

```

---

### **3️⃣ Create Virtual Ethernet Pairs**

```bash
ip link add veth_ns1_n type veth peer name veth_ns1_b
ip link add veth_ns2_n type veth peer name veth_ns2_b
ip link add veth_br0_router type veth peer name veth_br0_b
ip link add veth_br1_router type veth peer name veth_br1_b

```

---

### **4️⃣ Attach Interfaces to Namespaces**

```bash
ip link set veth_ns1_n netns ns1
ip link set veth_ns2_n netns ns2
ip link set veth_br0_router netns router-ns
ip link set veth_br1_router netns router-ns

```

---

### **5️⃣ Attach Bridges**

```bash
ip link set veth_ns1_b master br0
ip link set veth_ns2_b master br1
ip link set veth_br0_b master br0
ip link set veth_br1_b master br1

```

---

### **6️⃣ Assign IP Addresses**

```bash
# ns1
ip netns exec ns1 ip addr add 10.11.0.11/24 dev veth_ns1_n
ip netns exec ns1 ip link set veth_ns1_n up

# ns2
ip netns exec ns2 ip addr add 10.12.0.11/24 dev veth_ns2_n
ip netns exec ns2 ip link set veth_ns2_n up

# Router
ip netns exec router-ns ip addr add 10.11.0.22/24 dev veth_br0_router
ip netns exec router-ns ip addr add 10.12.0.22/24 dev veth_br1_router
ip netns exec router-ns ip link set veth_br0_router up
ip netns exec router-ns ip link set veth_br1_router up

```

---

### **7️⃣ Bring Up Interfaces**

```bash
ip link set veth_ns1_b up
ip link set veth_ns2_b up
ip link set veth_br0_b up
ip link set veth_br1_b up

```

---

### **8️⃣ Enable Packet Forwarding on Bridges**

```bash
sudo iptables -A FORWARD -o br0 -j ACCEPT
sudo iptables -A FORWARD -i br0 -j ACCEPT
sudo iptables -A FORWARD -i br1 -j ACCEPT
sudo iptables -A FORWARD -o br1 -j ACCEPT
```

---

### **9️⃣ Configure Routes**

```bash
# ns1 (Route to ns2 via router)
ip netns exec ns1 ip route add 10.12.0.0/24 via 10.11.0.22

# ns2 (Route to ns1 via router)
ip netns exec ns2 ip route add 10.11.0.0/24 via 10.12.0.22

```

---

### **Routing Table Overview:**

| Namespace | Destination Network | Next Hop (Gateway) |
| --- | --- | --- |
| `ns1` | `10.12.0.11/24` | `10.11.0.22` (router-ns) |
| `ns2` | `10.11.0.11/24` | `10.12.0.22` (router-ns) |
| `router-ns` | `10.11.0.1/16` & `10.12.0.1/16` | Directly Connected |
|  |  |  |
