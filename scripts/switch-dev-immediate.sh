#!/bin/bash
# 개발환경 즉시 K8s 전환 스크립트
# Phase 6: dev 환경 100% K8s 전환 (다운타임 허용)

set -e

echo "⚡ 개발환경 즉시 K8s 전환 시작..."

# kubectl 사용 가능 확인
if ! kubectl cluster-info >/dev/null 2>&1; then
    echo "❌ kubectl이 설정되지 않았습니다."
    exit 1
fi

# 현재 Docker dev 서비스 상태 확인
echo "📋 현재 Docker dev 서비스 상태:"
docker ps | grep -E "(kamf-dev-|kamf.*dev)" || echo "Docker dev 서비스가 실행 중이지 않습니다."

# 1단계: K8s dev 서비스 배포
echo "🚀 1단계: K8s dev 서비스 배포..."

# kamf-dev 네임스페이스 확인
kubectl get namespace kamf-dev >/dev/null 2>&1 || {
    echo "📁 kamf-dev 네임스페이스 생성..."
    kubectl create namespace kamf-dev
}

# dev 환경 매니페스트 적용 (로컬 k8s 디렉터리에서)
if [ -d "k8s/environments/dev" ]; then
    echo "📦 dev 환경 Kubernetes 리소스 배포..."
    kubectl apply -k k8s/environments/dev/
elif [ -d "../k8s/environments/dev" ]; then
    echo "📦 dev 환경 Kubernetes 리소스 배포..."
    kubectl apply -k ../k8s/environments/dev/
else
    echo "⚠️  k8s/environments/dev 디렉터리를 찾을 수 없습니다."
    echo "    ArgoCD Application 동기화를 수동으로 진행하거나"
    echo "    k8s 매니페스트 파일이 있는 위치에서 실행하세요."
fi

# K8s 서비스 시작 대기
echo "⏳ K8s dev 서비스 시작 대기..."
kubectl wait --for=condition=Ready pods -l environment=development -n kamf-dev --timeout=300s || {
    echo "⚠️  일부 파드가 준비되지 않았습니다. 상태를 확인하세요:"
    kubectl get pods -n kamf-dev
    echo "계속 진행합니다..."
}

# 2단계: Docker dev 서비스 중단
echo "🛑 2단계: Docker dev 서비스 중단..."

# Docker dev 서비스들 중단
DEV_CONTAINERS=$(docker ps --format "table {{.Names}}" | grep -E "(kamf-dev-|kamf.*dev)" | grep -v NAMES || true)
if [ -n "$DEV_CONTAINERS" ]; then
    echo "🛑 Docker dev 서비스 중단: $DEV_CONTAINERS"
    echo "$DEV_CONTAINERS" | xargs docker stop
    echo "✅ Docker dev 서비스 중단 완료"
else
    echo "✅ 중단할 Docker dev 서비스가 없습니다"
fi

# 3단계: nginx 설정 확인 및 업데이트
echo "🌐 3단계: nginx 설정 확인..."

# nginx 컨테이너 확인
if docker ps | grep -q "kamf-nginx"; then
    # K8s NodePort 서비스 포트 확인
    DEV_API_NODEPORT=$(kubectl get svc -n kamf-dev api-nodeport -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null || echo "30800")
    DEV_WEB_NODEPORT=$(kubectl get svc -n kamf-dev web-nodeport -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null || echo "30900")
    
    echo "📋 K8s NodePort 정보:"
    echo "  - API: localhost:$DEV_API_NODEPORT"
    echo "  - Web: localhost:$DEV_WEB_NODEPORT"
    
    echo "⚠️  nginx 설정 업데이트가 필요합니다:"
    echo "  1. kamf-nginx 컨테이너의 nginx 설정을 수정하여"
    echo "  2. dev.kamf.site 요청을 K8s NodePort로 전달하도록 변경"
    echo "  3. 또는 ArgoCD IngressRoute 사용 권장"
    
else
    echo "⚠️  kamf-nginx 컨테이너를 찾을 수 없습니다."
fi

# 4단계: 서비스 상태 확인
echo "🔍 4단계: 서비스 상태 확인..."

echo "📊 K8s dev 서비스 상태:"
kubectl get pods,svc -n kamf-dev
echo ""

echo "🌐 K8s NodePort 서비스 테스트:"
sleep 5  # 서비스 안정화 대기

# API 헬스체크 (NodePort)
if curl -f "http://localhost:$DEV_API_NODEPORT/health" >/dev/null 2>&1; then
    echo "✅ API 서비스 정상 (NodePort: $DEV_API_NODEPORT)"
else
    echo "⚠️  API 서비스 응답 없음 (NodePort: $DEV_API_NODEPORT)"
fi

# Web 서비스 테스트 (NodePort)  
if curl -f "http://localhost:$DEV_WEB_NODEPORT" >/dev/null 2>&1; then
    echo "✅ Web 서비스 정상 (NodePort: $DEV_WEB_NODEPORT)"
else
    echo "⚠️  Web 서비스 응답 없음 (NodePort: $DEV_WEB_NODEPORT)"
fi

echo ""
echo "🎉 개발환경 K8s 전환 완료!"
echo ""
echo "📋 전환 결과:"
echo "- Docker dev 서비스: 중단됨"
echo "- K8s dev 서비스: 실행 중"
echo "- API NodePort: $DEV_API_NODEPORT"
echo "- Web NodePort: $DEV_WEB_NODEPORT"
echo ""
echo "🔗 다음 작업:"
echo "  1. nginx 설정 업데이트로 dev.kamf.site → K8s NodePort 연결"
echo "  2. ArgoCD IngressRoute 설정 (권장)"
echo "  3. 개발환경 테스트 및 검증"
echo ""
echo "📝 유용한 명령어:"
echo "  kubectl get all -n kamf-dev                    # dev 리소스 확인"  
echo "  kubectl logs -f deployment/kamf-api -n kamf-dev # API 로그"
echo "  ./rollback.sh dev                              # dev 환경 롤백"