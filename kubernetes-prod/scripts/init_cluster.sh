cat > /etc/sysctl.d/99-kubernetes-cri.conf <<EOF
net.bridge.bridge-nf-calliptables= 1
net.ipv4.ip_forward= 1
net.bridge.bridge-nf-call-ip6tables= 1
EOF
systemctl restart systemd-sysctl.service
sudo modprobe overlay
sudo modprobe br_netfilter
cat > /etc/modules-load.d/containerd.conf <<EOF
overlay
br_netfilter
EOF
systemctl restart systemd-modules-load.service
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
sudo swapoff -a
sudo apt-get update
mkdir /etc/apt/keyrings && curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key 
sudo apt-get install -y containerd apt-transport-https ca-certificates curl gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl

