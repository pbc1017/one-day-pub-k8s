#!/bin/bash
# nginx-ingress-controller 설치 스크립트
# Phase 6: Ingress Controller 설치

set -e

echo "🌐 nginx-ingress-controller 설치 시작..."

# kubectl 사용 가능 확인
if ! kubectl cluster-info >/dev/null 2>&1; then
    echo "❌ kubectl이 설정되지 않았습니다. setup-k3s.sh를 먼저 실행하세요."
    exit 1
fi

# Helm 설치 확인
if ! command -v helm &> /dev/null; then
    echo "🔧 Helm 설치 중..."
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi

# nginx-ingress Helm 레포지토리 추가
echo "📦 nginx-ingress Helm 레포지토리 추가..."
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

# nginx-ingress-controller 설치
echo "⚙️  nginx-ingress-controller 설치 중..."
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.hostPort.enabled=true \
  --set controller.hostPort.ports.http=80 \
  --set controller.hostPort.ports.https=443 \
  --set controller.service.type=ClusterIP \
  --set controller.kind=DaemonSet \
  --set controller.watchIngressWithoutClass=true \
  --set controller.ingressClassResource.default=true \
  --wait

# nginx-ingress 상태 확인
echo "✅ nginx-ingress-controller 상태 확인..."
kubectl get pods -n ingress-nginx
kubectl get svc -n ingress-nginx
kubectl get ingressclass

echo ""
echo "🎉 nginx-ingress-controller 설치 완료!"
echo ""
echo "📋 설치 정보:"
echo "- Namespace: ingress-nginx"
echo "- Type: DaemonSet (HostPort 80, 443)"
echo "- IngressClass: nginx (default)"
echo ""
echo "🔗 다음 단계:"
echo "  ./install-cert-manager.sh   # cert-manager 설치"
echo "  kubectl get pods -n ingress-nginx  # 파드 상태 확인"
