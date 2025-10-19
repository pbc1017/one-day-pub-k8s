#!/bin/bash
# One Day Pub K8s 통합 배포 스크립트
# Phase 6: 전체 인프라 배포 자동화

set -e

echo "🚀 One Day Pub K8s 배포 시작..."
echo ""

# 현재 사용자 확인
if [ "$USER" != "kws" ]; then
    echo "⚠️  kws 사용자로 실행해주세요"
    exit 1
fi

# 스크립트 디렉터리 확인
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 색상 정의
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 단계별 배포
echo "═══════════════════════════════════════════════"
echo "  Step 1/6: K3s 클러스터 설치"
echo "═══════════════════════════════════════════════"
if kubectl cluster-info >/dev/null 2>&1; then
    echo -e "${YELLOW}⚠️  K3s가 이미 설치되어 있습니다. 건너뜁니다.${NC}"
else
    chmod +x setup-k3s.sh
    ./setup-k3s.sh
fi
echo ""

echo "═══════════════════════════════════════════════"
echo "  Step 2/6: nginx-ingress-controller 설치"
echo "═══════════════════════════════════════════════"
if kubectl get namespace ingress-nginx >/dev/null 2>&1; then
    echo -e "${YELLOW}⚠️  nginx-ingress가 이미 설치되어 있습니다. 건너뜁니다.${NC}"
else
    chmod +x install-nginx-ingress.sh
    ./install-nginx-ingress.sh
fi
echo ""

echo "═══════════════════════════════════════════════"
echo "  Step 3/6: cert-manager 설치"
echo "═══════════════════════════════════════════════"
if kubectl get namespace cert-manager >/dev/null 2>&1; then
    echo -e "${YELLOW}⚠️  cert-manager가 이미 설치되어 있습니다. 건너뜁니다.${NC}"
else
    chmod +x install-cert-manager.sh
    ./install-cert-manager.sh
fi
echo ""

echo "═══════════════════════════════════════════════"
echo "  Step 4/6: ArgoCD 설치"
echo "═══════════════════════════════════════════════"
if kubectl get namespace argocd >/dev/null 2>&1; then
    echo -e "${YELLOW}⚠️  ArgoCD가 이미 설치되어 있습니다. 건너뜁니다.${NC}"
else
    chmod +x install-argocd.sh
    ./install-argocd.sh
fi
echo ""

echo "═══════════════════════════════════════════════"
echo "  Step 5/6: ArgoCD Root Application 배포"
echo "═══════════════════════════════════════════════"
if kubectl get application -n argocd one-day-pub-root >/dev/null 2>&1; then
    echo -e "${YELLOW}⚠️  Root Application이 이미 배포되어 있습니다.${NC}"
else
    echo "📦 Root Application 배포 중..."
    kubectl apply -f "$SCRIPT_DIR/../.argocd/applications/root-app.yaml"
    
    # Root Application이 다른 Application들을 배포할 때까지 대기
    echo "⏳ Root Application 동기화 대기..."
    sleep 10
    kubectl wait --for=condition=Ready application/one-day-pub-root -n argocd --timeout=300s || true
fi
echo ""

echo "═══════════════════════════════════════════════"
echo "  Step 6/6: 초기 Secrets 안내"
echo "═══════════════════════════════════════════════"
echo -e "${YELLOW}⚠️  Secrets는 GitHub Actions에서 자동으로 주입됩니다${NC}"
echo ""
echo "수동으로 Secrets를 생성하려면 다음 명령어를 사용하세요:"
echo ""
echo "# Development Secrets"
echo "kubectl create secret generic one-day-pub-secrets -n one-day-pub-dev \\"
echo "  --from-literal=db-username='YOUR_DB_USER' \\"
echo "  --from-literal=db-password='YOUR_DB_PASS' \\"
echo "  --from-literal=mysql-root-password='YOUR_MYSQL_ROOT_PASS' \\"
echo "  --from-literal=jwt-secret='YOUR_JWT_SECRET' \\"
echo "  --from-literal=refresh-token-secret='YOUR_REFRESH_SECRET' \\"
echo "  --from-literal=nextauth-secret='YOUR_NEXTAUTH_SECRET' \\"
echo "  --from-literal=twilio-account-sid='YOUR_TWILIO_SID' \\"
echo "  --from-literal=twilio-auth-token='YOUR_TWILIO_TOKEN' \\"
echo "  --from-literal=twilio-service-sid='YOUR_TWILIO_SERVICE_SID' \\"
echo "  --from-literal=mailgun-api-key='YOUR_MAILGUN_KEY' \\"
echo "  --from-literal=mailgun-domain='YOUR_MAILGUN_DOMAIN' \\"
echo "  --from-literal=mailgun-from-email='YOUR_MAILGUN_EMAIL'"
echo ""
echo "# Production Secrets (동일한 형식으로 -n one-day-pub-prod)"
echo ""

# 외부 IP 확인
EXTERNAL_IP=$(curl -s ifconfig.me || echo "210.117.237.104")

echo ""
echo "═══════════════════════════════════════════════"
echo -e "  ${GREEN}✅ 배포 완료!${NC}"
echo "═══════════════════════════════════════════════"
echo ""
echo "📋 설치된 컴포넌트:"
echo "  ✓ K3s 클러스터"
echo "  ✓ nginx-ingress-controller"
echo "  ✓ cert-manager"
echo "  ✓ ArgoCD"
echo ""
echo "🌐 서비스 접속 정보:"
echo "  - ArgoCD UI: https://argocd.one-day-pub.site"
echo "  - Dev 환경:  https://dev.one-day-pub.site"
echo "  - Prod 환경: https://one-day-pub.site"
echo ""
echo "⚠️  DNS 설정 필요:"
echo "  argocd.one-day-pub.site  → $EXTERNAL_IP"
echo "  dev.one-day-pub.site     → $EXTERNAL_IP"
echo "  one-day-pub.site         → $EXTERNAL_IP"
echo "  www.one-day-pub.site     → $EXTERNAL_IP"
echo ""
echo "🔑 ArgoCD 로그인 정보:"
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>/dev/null | base64 -d || echo "비밀번호를 가져올 수 없습니다")
echo "  Username: admin"
echo "  Password: $ARGOCD_PASSWORD"
echo ""
echo "📝 다음 단계:"
echo "  1. DNS A 레코드 설정"
echo "  2. ArgoCD UI 접속 및 로그인"
echo "  3. GitHub Actions로 첫 배포 트리거"
echo "  4. ArgoCD에서 애플리케이션 동기화 상태 확인"
echo ""
echo "🔧 유용한 명령어:"
echo "  kubectl get all -A              # 전체 리소스 확인"
echo "  kubectl get applications -n argocd  # ArgoCD 애플리케이션 확인"
echo "  kubectl get ingress -A          # Ingress 확인"
echo "  kubectl get certificates -A     # TLS 인증서 확인"
echo ""
