#!/bin/bash
# 시스템 헬스체크 스크립트
# Phase 6: K8s + Docker 하이브리드 환경 모니터링

set -e

# 컬러 출력 설정
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 상태 표시 함수
status_ok() { echo -e "${GREEN}✅ $1${NC}"; }
status_warn() { echo -e "${YELLOW}⚠️  $1${NC}"; }
status_error() { echo -e "${RED}❌ $1${NC}"; }
status_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }

echo "🌡 KAMF 시스템 헬스체크 시작..."
echo "⏰ 실행 시간: $(date)"
echo ""

# 1. 시스템 리소스 확인
echo "📊 1. 시스템 리소스 확인"
echo "────────────────────────────────"

# 메모리 사용량
MEMORY_USAGE=$(free | grep Mem | awk '{printf "%.0f", $3/$2 * 100.0}')
MEMORY_TOTAL=$(free -h | grep Mem | awk '{print $2}')
MEMORY_USED=$(free -h | grep Mem | awk '{print $3}')

echo "💾 메모리: $MEMORY_USED / $MEMORY_TOTAL (${MEMORY_USAGE}%)"
if [ "$MEMORY_USAGE" -lt 70 ]; then
    status_ok "메모리 사용량 정상"
elif [ "$MEMORY_USAGE" -lt 85 ]; then
    status_warn "메모리 사용량 높음 (${MEMORY_USAGE}%)"
else
    status_error "메모리 사용량 위험 (${MEMORY_USAGE}%)"
fi

# CPU 로드 평균
LOAD_AVG=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')
echo "🖥️  CPU 로드 평균: $LOAD_AVG"

# 디스크 사용량
DISK_USAGE=$(df / | grep / | awk '{print $5}' | sed 's/%//g')
echo "💿 디스크 사용량: ${DISK_USAGE}%"
if [ "$DISK_USAGE" -lt 80 ]; then
    status_ok "디스크 사용량 정상"
elif [ "$DISK_USAGE" -lt 90 ]; then
    status_warn "디스크 사용량 높음 (${DISK_USAGE}%)"
else
    status_error "디스크 사용량 위험 (${DISK_USAGE}%)"
fi

echo ""

# 2. K8s 클러스터 상태 확인
echo "☸️  2. Kubernetes 클러스터 상태"
echo "────────────────────────────────"

if command -v kubectl >/dev/null 2>&1 && kubectl cluster-info >/dev/null 2>&1; then
    # 노드 상태
    NODE_STATUS=$(kubectl get nodes --no-headers | awk '{print $2}' | head -1)
    if [ "$NODE_STATUS" = "Ready" ]; then
        status_ok "K8s 노드 상태: Ready"
    else
        status_error "K8s 노드 상태: $NODE_STATUS"
    fi
    
    # 시스템 파드 상태
    SYSTEM_PODS_NOT_READY=$(kubectl get pods -n kube-system --no-headers | grep -v Running | grep -v Completed | wc -l)
    if [ "$SYSTEM_PODS_NOT_READY" -eq 0 ]; then
        status_ok "시스템 파드 모두 정상 실행"
    else
        status_warn "시스템 파드 $SYSTEM_PODS_NOT_READY 개 비정상"
        kubectl get pods -n kube-system --no-headers | grep -v Running | grep -v Completed
    fi
    
    # KAMF 파드 상태
    echo ""
    echo "📦 KAMF 파드 상태:"
    
    # dev 환경
    if kubectl get namespace kamf-dev >/dev/null 2>&1; then
        DEV_PODS_NOT_READY=$(kubectl get pods -n kamf-dev --no-headers | grep -v Running | grep -v Completed | wc -l)
        DEV_PODS_TOTAL=$(kubectl get pods -n kamf-dev --no-headers | wc -l)
        echo "  🔹 kamf-dev: $((DEV_PODS_TOTAL - DEV_PODS_NOT_READY))/$DEV_PODS_TOTAL 파드 Ready"
        if [ "$DEV_PODS_NOT_READY" -gt 0 ]; then
            status_warn "kamf-dev 파드 $DEV_PODS_NOT_READY 개 비정상"
        fi
    else
        status_info "kamf-dev 네임스페이스 없음"
    fi
    
    # prod 환경
    if kubectl get namespace kamf-prod >/dev/null 2>&1; then
        PROD_PODS_NOT_READY=$(kubectl get pods -n kamf-prod --no-headers | grep -v Running | grep -v Completed | wc -l)
        PROD_PODS_TOTAL=$(kubectl get pods -n kamf-prod --no-headers | wc -l)
        echo "  🔹 kamf-prod: $((PROD_PODS_TOTAL - PROD_PODS_NOT_READY))/$PROD_PODS_TOTAL 파드 Ready"
        if [ "$PROD_PODS_NOT_READY" -gt 0 ]; then
            status_error "kamf-prod 파드 $PROD_PODS_NOT_READY 개 비정상"
        fi
    else
        status_info "kamf-prod 네임스페이스 없음"
    fi
    
    # ArgoCD 상태
    if kubectl get namespace argocd >/dev/null 2>&1; then
        ARGOCD_PODS_NOT_READY=$(kubectl get pods -n argocd --no-headers | grep -v Running | grep -v Completed | wc -l)
        ARGOCD_PODS_TOTAL=$(kubectl get pods -n argocd --no-headers | wc -l)
        echo "  🔹 argocd: $((ARGOCD_PODS_TOTAL - ARGOCD_PODS_NOT_READY))/$ARGOCD_PODS_TOTAL 파드 Ready"
        if [ "$ARGOCD_PODS_NOT_READY" -gt 0 ]; then
            status_warn "argocd 파드 $ARGOCD_PODS_NOT_READY 개 비정상"
        fi
    else
        status_info "argocd 네임스페이스 없음"
    fi
    
else
    status_error "Kubernetes 클러스터 접근 불가"
fi

echo ""

# 3. Docker 서비스 상태 확인
echo "🐳 3. Docker 서비스 상태"  
echo "────────────────────────────"

if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
    # KAMF 컨테이너 상태
    KAMF_CONTAINERS=$(docker ps --format "table {{.Names}}\t{{.Status}}" | grep kamf)
    if [ -n "$KAMF_CONTAINERS" ]; then
        echo "📦 KAMF 컨테이너:"
        echo "$KAMF_CONTAINERS"
        
        # nginx 컨테이너 특별 확인
        if docker ps | grep -q "kamf-nginx"; then
            status_ok "nginx 리버스 프록시 실행 중"
        else
            status_error "nginx 리버스 프록시 중단됨"
        fi
    else
        status_info "실행 중인 KAMF 컨테이너 없음"
    fi
else
    status_error "Docker 접근 불가"
fi

echo ""

# 4. 웹사이트 접속 테스트
echo "🌐 4. 웹사이트 접속 테스트"
echo "────────────────────────────"

# 외부 IP 확인
EXTERNAL_IP=$(curl -s ifconfig.me 2>/dev/null || echo "210.117.237.104")
echo "🌍 외부 IP: $EXTERNAL_IP"

# 메인 사이트 테스트
echo ""
echo "🌐 메인 사이트 테스트:"

# HTTP 접속 테스트
if curl -f -s -m 10 "http://$EXTERNAL_IP/" >/dev/null 2>&1; then
    status_ok "HTTP 접속 성공 (포트 80)"
else
    status_error "HTTP 접속 실패 (포트 80)"
fi

# HTTPS 접속 테스트 (있는 경우)
if curl -f -s -m 10 "https://$EXTERNAL_IP/" >/dev/null 2>&1; then
    status_ok "HTTPS 접속 성공 (포트 443)"
else
    status_warn "HTTPS 접속 실패 (포트 443)"
fi

# API 헬스체크
echo ""
echo "🚀 API 서비스 테스트:"

# 운영 API (nginx 통해서)
if curl -f -s -m 10 "http://$EXTERNAL_IP/api/health" >/dev/null 2>&1; then
    status_ok "운영 API 응답 정상"
else
    status_error "운영 API 응답 없음"
fi

# NodePort 직접 테스트 (K8s 서비스)
echo ""
echo "🔌 NodePort 서비스 테스트:"

# dev API NodePort
DEV_API_PORT=$(kubectl get svc -n kamf-dev api-nodeport -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null || echo "30800")
if curl -f -s -m 5 "http://localhost:$DEV_API_PORT/health" >/dev/null 2>&1; then
    status_ok "dev API NodePort ($DEV_API_PORT) 정상"
else
    status_warn "dev API NodePort ($DEV_API_PORT) 응답 없음"
fi

# prod API NodePort
PROD_API_PORT=$(kubectl get svc -n kamf-prod api-nodeport -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null || echo "30801")
if curl -f -s -m 5 "http://localhost:$PROD_API_PORT/health" >/dev/null 2>&1; then
    status_ok "prod API NodePort ($PROD_API_PORT) 정상"
else
    status_warn "prod API NodePort ($PROD_API_PORT) 응답 없음"
fi

echo ""

# 5. 종합 상태 판정
echo "📋 5. 종합 상태 판정"
echo "────────────────────────────"

CRITICAL_ISSUES=0
WARNING_ISSUES=0

# 메모리 위험 수준
if [ "$MEMORY_USAGE" -gt 85 ]; then
    CRITICAL_ISSUES=$((CRITICAL_ISSUES + 1))
elif [ "$MEMORY_USAGE" -gt 70 ]; then
    WARNING_ISSUES=$((WARNING_ISSUES + 1))
fi

# 디스크 위험 수준
if [ "$DISK_USAGE" -gt 90 ]; then
    CRITICAL_ISSUES=$((CRITICAL_ISSUES + 1))
elif [ "$DISK_USAGE" -gt 80 ]; then
    WARNING_ISSUES=$((WARNING_ISSUES + 1))
fi

echo "🎯 헬스체크 요약:"
echo "  - 심각한 문제: $CRITICAL_ISSUES 개"
echo "  - 주의 사항: $WARNING_ISSUES 개"

if [ "$CRITICAL_ISSUES" -eq 0 ] && [ "$WARNING_ISSUES" -eq 0 ]; then
    status_ok "시스템 상태 양호 🎉"
    exit 0
elif [ "$CRITICAL_ISSUES" -eq 0 ]; then
    status_warn "시스템에 주의사항이 있습니다"
    exit 1
else
    status_error "시스템에 심각한 문제가 있습니다!"
    exit 2
fi