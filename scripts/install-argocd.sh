#!/bin/bash
# ArgoCD 설치 스크립트
# Phase 6: GitOps 플랫폼 설치 및 One Day Pub 레포 연결

set -e

echo "🤖 ArgoCD 설치 시작..."

# kubectl 사용 가능 확인
if ! kubectl cluster-info >/dev/null 2>&1; then
    echo "❌ kubectl이 설정되지 않았습니다. setup-k3s.sh를 먼저 실행하세요."
    exit 1
fi

# ArgoCD namespace 생성
echo "📁 ArgoCD 네임스페이스 생성..."
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

# ArgoCD 설치
echo "📦 ArgoCD 설치..."
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# ArgoCD 파드 시작 대기
echo "⏳ ArgoCD 파드 시작 대기..."
kubectl wait --for=condition=Ready pods --all -n argocd --timeout=300s

# ArgoCD 서비스 확인
echo "🔍 ArgoCD 서비스 상태 확인..."
kubectl get pods -n argocd
kubectl get svc -n argocd

# ArgoCD 초기 admin 비밀번호 확인
echo "🔑 ArgoCD 초기 admin 비밀번호 확인..."
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
echo "ArgoCD admin 비밀번호: $ARGOCD_PASSWORD"

# ArgoCD Server를 NodePort로 노출 (Traefik IngressRoute 대신)
echo "🌐 ArgoCD Server NodePort 서비스 생성..."
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: argocd-server-nodeport
  namespace: argocd
  labels:
    app.kubernetes.io/component: server
    app.kubernetes.io/name: argocd-server
    app.kubernetes.io/part-of: argocd
spec:
  type: NodePort
  ports:
  - port: 80
    protocol: TCP
    targetPort: 8080
    nodePort: 30080
    name: server
  - port: 443
    protocol: TCP
    targetPort: 8080
    nodePort: 30443
    name: server-https
  selector:
    app.kubernetes.io/name: argocd-server
EOF

# ArgoCD CLI 설치
echo "🔧 ArgoCD CLI 설치..."
if ! command -v argocd &> /dev/null; then
    curl -sSL -o /tmp/argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
    chmod +x /tmp/argocd
    sudo mv /tmp/argocd /usr/local/bin/argocd
    echo "✅ ArgoCD CLI 설치 완료"
else
    echo "✅ ArgoCD CLI 이미 설치되어 있음"
fi

# ArgoCD 서버 insecure 모드 설정 (HTTP 접근 허용)
echo "🔓 ArgoCD 서버 insecure 모드 설정..."
kubectl patch configmap argocd-cmd-params-cm -n argocd --patch '{"data":{"server.insecure":"true"}}'
kubectl rollout restart deployment argocd-server -n argocd
kubectl rollout status deployment argocd-server -n argocd --timeout=120s

# 외부 IP 확인
EXTERNAL_IP=$(curl -s ifconfig.me || echo "210.117.237.104")

echo ""
echo "🎉 ArgoCD 설치 완료!"
echo ""
echo "📋 ArgoCD 접속 정보:"
echo "- URL: http://$EXTERNAL_IP:30080"
echo "- Username: admin"
echo "- Password: $ARGOCD_PASSWORD"
echo ""
echo "🔗 다음 단계:"
echo "  1. 웹 브라우저에서 ArgoCD UI 접속 확인"
echo "  2. One Day Pub GitOps 레포 연결"
echo "  3. ./connect-gitops.sh 실행 (별도 작성 필요)"
echo ""
echo "📝 참고 명령어:"
echo "  kubectl get pods -n argocd          # ArgoCD 파드 상태"
echo "  kubectl logs -n argocd deployment/argocd-server  # 로그 확인"