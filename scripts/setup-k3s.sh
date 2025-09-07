#!/bin/bash
# K3s 설치 스크립트
# Phase 6: 실제 서버 K3s 클러스터 설치

set -e

echo "🚀 K3s 클러스터 설치 시작..."

# 현재 사용자 확인
if [ "$USER" != "kamf" ]; then
    echo "⚠️  kamf 사용자로 실행해주세요"
    exit 1
fi

# 시스템 업데이트
echo "📦 시스템 패키지 업데이트..."
sudo apt-get update -qq

# 필수 패키지 설치
echo "🔧 필수 패키지 설치..."
sudo apt-get install -y \
    curl \
    wget \
    apt-transport-https \
    ca-certificates \
    software-properties-common \
    jq

# 외부 IP 확인
EXTERNAL_IP=$(curl -s ifconfig.me || curl -s ipinfo.io/ip || echo "210.117.237.104")
echo "🌐 외부 IP: $EXTERNAL_IP"

# K3s 설치 (Traefik 포함, ServiceLB만 비활성화)
echo "☸️  K3s 설치 시작 (Traefik Ingress 포함)..."
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--disable=servicelb --node-external-ip=$EXTERNAL_IP --write-kubeconfig-mode=644" sh -

# K3s 서비스 상태 확인
echo "✅ K3s 서비스 상태 확인..."
sudo systemctl status k3s --no-pager -l

# kubectl 설정
echo "🔑 kubectl 설정..."
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $(id -u):$(id -g) ~/.kube/config
export KUBECONFIG=~/.kube/config

# bashrc에 KUBECONFIG 추가
if ! grep -q "KUBECONFIG" ~/.bashrc; then
    echo 'export KUBECONFIG=~/.kube/config' >> ~/.bashrc
    echo "📝 KUBECONFIG를 ~/.bashrc에 추가했습니다"
fi

# 클러스터 상태 확인
echo "📊 클러스터 상태 확인..."
kubectl get nodes -o wide
kubectl get pods -A

# Traefik 상태 확인
echo "🌐 Traefik Ingress Controller 확인..."
kubectl get pods -n kube-system -l app.kubernetes.io/name=traefik

# KAMF 네임스페이스 생성
echo "📁 KAMF 네임스페이스 생성..."
kubectl create namespace kamf-dev --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace kamf-prod --dry-run=client -o yaml | kubectl apply -f -

# 네임스페이스 확인
kubectl get namespaces | grep kamf

echo ""
echo "🎉 K3s 클러스터 설치 완료!"
echo ""
echo "📋 설치 정보:"
echo "- K3s 버전: $(k3s --version | head -1)"
echo "- 외부 IP: $EXTERNAL_IP" 
echo "- Kubeconfig: ~/.kube/config"
echo "- 네임스페이스: kamf-dev, kamf-prod"
echo ""
echo "🔗 다음 단계:"
echo "  ./install-argocd.sh     # ArgoCD 설치"
echo "  kubectl get all -A      # 전체 리소스 확인"