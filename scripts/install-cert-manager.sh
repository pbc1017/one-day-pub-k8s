#!/bin/bash
# cert-manager 설치 스크립트
# Phase 6: TLS 인증서 자동 관리

set -e

echo "🔐 cert-manager 설치 시작..."

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

# cert-manager Helm 레포지토리 추가
echo "📦 cert-manager Helm 레포지토리 추가..."
helm repo add jetstack https://charts.jetstack.io
helm repo update

# cert-manager 설치
echo "⚙️  cert-manager 설치 중..."
helm upgrade --install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --set installCRDs=true \
  --wait

# cert-manager 파드 시작 대기
echo "⏳ cert-manager 파드 시작 대기..."
kubectl wait --for=condition=Ready pods --all -n cert-manager --timeout=300s

# Let's Encrypt ClusterIssuer 생성
echo "📝 Let's Encrypt ClusterIssuer 생성..."
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: admin@one-day-pub.site
    privateKeySecretRef:
      name: letsencrypt-prod-account-key
    solvers:
    - http01:
        ingress:
          class: nginx
EOF

# ClusterIssuer 상태 확인
echo "✅ ClusterIssuer 상태 확인..."
kubectl get clusterissuer

echo ""
echo "🎉 cert-manager 설치 완료!"
echo ""
echo "📋 설치 정보:"
echo "- Namespace: cert-manager"
echo "- ClusterIssuer: letsencrypt-prod"
echo "- Email: admin@one-day-pub.site"
echo ""
echo "🔗 다음 단계:"
echo "  ./install-argocd.sh          # ArgoCD 설치"
echo "  kubectl get pods -n cert-manager  # 파드 상태 확인"
echo "  kubectl get clusterissuer    # ClusterIssuer 확인"
