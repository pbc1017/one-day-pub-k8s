#!/bin/bash
# 단계별 롤백 스크립트  
# Phase 6: K8s → Docker 안전한 롤백

set -e

# 컬러 출력 설정
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 사용법 체크
if [ $# -lt 1 ]; then
    echo "사용법: $0 <롤백_대상>"
    echo ""
    echo "롤백 대상:"
    echo "  dev        - 개발환경만 롤백 (K8s → Docker)"
    echo "  prod       - 운영환경만 롤백 (K8s → Docker)"  
    echo "  nginx      - nginx 설정만 원복"
    echo "  argocd     - ArgoCD만 제거"
    echo "  k3s        - K3s 클러스터 완전 제거"
    echo "  all        - 전체 롤백 (Docker 환경으로 완전 복원)"
    echo ""
    echo "예시:"
    echo "  $0 dev      # 개발환경 롤백"
    echo "  $0 nginx    # nginx 설정 원복"
    echo "  $0 all      # 전체 롤백"
    exit 1
fi

ROLLBACK_TARGET=$1

echo -e "${BLUE}♾️  One Day Pub 롤백 시작: $ROLLBACK_TARGET${NC}"
echo "⏰ 실행 시간: $(date)"
echo ""

# 확인 프롬프트
echo -e "${YELLOW}⚠️  경고: 이 작업은 되돌릴 수 없습니다!${NC}"
echo "롤백 대상: $ROLLBACK_TARGET"
echo ""
read -p "정말로 롤백을 진행하시겠습니까? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "❌ 롤백이 취소되었습니다."
    exit 1
fi

echo ""

# 롤백 함수들
rollback_dev() {
    echo -e "${BLUE}🔄 개발환경 롤백 시작...${NC}"
    
    # K8s dev 서비스 중단
    if kubectl get namespace one-day-pub-dev >/dev/null 2>&1; then
        echo "🛑 K8s dev 서비스 중단..."
        kubectl delete namespace one-day-pub-dev --ignore-not-found=true
        echo "✅ one-day-pub-dev 네임스페이스 삭제 완료"
    fi
    
    # Docker dev 서비스 시작
    echo "🚀 Docker dev 서비스 시작..."
    if [ -f "deploy/docker-compose.dev.yml" ]; then
        docker-compose -f deploy/docker-compose.dev.yml up -d
    elif [ -f "docker-compose.dev.yml" ]; then
        docker-compose -f docker-compose.dev.yml up -d
    else
        echo "⚠️  docker-compose.dev.yml 파일을 찾을 수 없습니다."
        echo "수동으로 Docker dev 서비스를 시작하세요:"
        echo "  docker run -d --name one-day-pub-dev-api chansparcs/one-day-pub-api:dev"
        echo "  docker run -d --name one-day-pub-dev-web chansparcs/one-day-pub-web:dev"
    fi
    
    echo -e "${GREEN}✅ 개발환경 롤백 완료${NC}"
}

rollback_prod() {
    echo -e "${BLUE}🔄 운영환경 롤백 시작...${NC}"
    
    # nginx upstream을 100% Docker로 복원
    echo "🌐 nginx upstream 100% Docker 복원..."
    if docker ps | grep -q "one-day-pub-nginx"; then
        # nginx 백업 설정 복원
        BACKUP_FILE=$(docker exec one-day-pub-nginx ls -t /etc/nginx/conf.d/one-day-pub-common.conf.backup.* 2>/dev/null | head -1 || echo "")
        if [ -n "$BACKUP_FILE" ]; then
            echo "💾 nginx 설정 백업에서 복원: $BACKUP_FILE"
            docker exec one-day-pub-nginx cp "$BACKUP_FILE" /etc/nginx/conf.d/one-day-pub-common.conf
            docker exec one-day-pub-nginx nginx -t
            docker exec one-day-pub-nginx nginx -s reload
            echo "✅ nginx 설정 복원 완료"
        else
            echo "⚠️  nginx 백업 설정을 찾을 수 없습니다."
            echo "수동으로 nginx upstream을 Docker로 변경하세요."
        fi
    fi
    
    # Docker prod 서비스 시작
    echo "🚀 Docker prod 서비스 시작..."
    docker start one-day-pub-api one-day-pub-web 2>/dev/null || {
        echo "⚠️  Docker prod 서비스 시작 실패. 수동으로 확인하세요."
    }
    
    # K8s prod 서비스 중단 (선택적)
    echo "🛑 K8s prod 서비스 중단..."
    if kubectl get namespace one-day-pub-prod >/dev/null 2>&1; then
        kubectl delete namespace one-day-pub-prod --ignore-not-found=true
        echo "✅ one-day-pub-prod 네임스페이스 삭제 완료"
    fi
    
    echo -e "${GREEN}✅ 운영환경 롤백 완료${NC}"
}

rollback_nginx() {
    echo -e "${BLUE}🔄 nginx 설정 롤백 시작...${NC}"
    
    if docker ps | grep -q "one-day-pub-nginx"; then
        # 최신 백업 파일 찾기
        BACKUP_FILE=$(docker exec one-day-pub-nginx ls -t /etc/nginx/conf.d/one-day-pub-common.conf.backup.* 2>/dev/null | head -1 || echo "")
        if [ -n "$BACKUP_FILE" ]; then
            echo "💾 nginx 설정 백업에서 복원: $BACKUP_FILE"
            docker exec one-day-pub-nginx cp "$BACKUP_FILE" /etc/nginx/conf.d/one-day-pub-common.conf
            
            # 설정 검증
            if docker exec one-day-pub-nginx nginx -t; then
                docker exec one-day-pub-nginx nginx -s reload
                echo -e "${GREEN}✅ nginx 설정 롤백 완료${NC}"
            else
                echo -e "${RED}❌ nginx 설정 오류! 수동 확인 필요${NC}"
                exit 1
            fi
        else
            echo -e "${YELLOW}⚠️  nginx 백업 설정을 찾을 수 없습니다${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️  one-day-pub-nginx 컨테이너를 찾을 수 없습니다${NC}"
    fi
}

rollback_argocd() {
    echo -e "${BLUE}🔄 ArgoCD 롤백 시작...${NC}"
    
    if kubectl get namespace argocd >/dev/null 2>&1; then
        echo "🛑 ArgoCD 제거..."
        kubectl delete namespace argocd --timeout=60s
        echo "✅ ArgoCD 제거 완료"
    else
        echo "⚠️  ArgoCD가 설치되어 있지 않습니다."
    fi
    
    # ArgoCD CLI 제거 (선택적)
    if command -v argocd >/dev/null 2>&1; then
        echo "🗑️  ArgoCD CLI 제거..."
        sudo rm -f /usr/local/bin/argocd
        echo "✅ ArgoCD CLI 제거 완료"
    fi
    
    echo -e "${GREEN}✅ ArgoCD 롤백 완료${NC}"
}

rollback_k3s() {
    echo -e "${BLUE}🔄 K3s 클러스터 롤백 시작...${NC}"
    
    # K3s 언인스톨
    if command -v k3s >/dev/null 2>&1; then
        echo "🛑 K3s 언인스톨..."
        /usr/local/bin/k3s-uninstall.sh 2>/dev/null || {
            echo "⚠️  K3s 언인스톨 스크립트 실행 실패"
            # 수동 정리
            sudo systemctl stop k3s 2>/dev/null || true
            sudo systemctl disable k3s 2>/dev/null || true
            sudo rm -rf /var/lib/rancher/k3s
            sudo rm -rf /etc/rancher/k3s
            sudo rm -f /usr/local/bin/k3s*
        }
        echo "✅ K3s 언인스톨 완료"
    else
        echo "⚠️  K3s가 설치되어 있지 않습니다."
    fi
    
    # kubectl 설정 정리
    echo "🗑️  kubectl 설정 정리..."
    rm -rf ~/.kube
    
    # bashrc에서 KUBECONFIG 제거
    if grep -q "KUBECONFIG" ~/.bashrc; then
        sed -i '/KUBECONFIG/d' ~/.bashrc
        echo "✅ ~/.bashrc에서 KUBECONFIG 제거 완료"
    fi
    
    echo -e "${GREEN}✅ K3s 롤백 완료${NC}"
}

rollback_all() {
    echo -e "${BLUE}🔄 전체 롤백 시작...${NC}"
    echo "이 작업은 시스템을 완전히 Docker 환경으로 되돌립니다."
    echo ""
    
    # 단계별 롤백
    rollback_dev
    echo ""
    rollback_prod  
    echo ""
    rollback_nginx
    echo ""
    rollback_argocd
    echo ""
    rollback_k3s
    echo ""
    
    # 모든 Docker 서비스 시작 확인
    echo "🚀 모든 Docker 서비스 시작 확인..."
    docker start one-day-pub-nginx one-day-pub-api one-day-pub-web one-day-pub-mysql 2>/dev/null || {
        echo "⚠️  일부 Docker 서비스 시작 실패. 수동으로 확인하세요."
    }
    
    echo -e "${GREEN}🎉 전체 롤백 완료! 시스템이 Docker 환경으로 복원되었습니다.${NC}"
}

# 롤백 실행
case $ROLLBACK_TARGET in
    "dev")
        rollback_dev
        ;;
    "prod")
        rollback_prod
        ;;
    "nginx")
        rollback_nginx
        ;;
    "argocd")
        rollback_argocd
        ;;
    "k3s")
        rollback_k3s
        ;;
    "all")
        rollback_all
        ;;
    *)
        echo -e "${RED}❌ 지원되지 않는 롤백 대상: $ROLLBACK_TARGET${NC}"
        echo "지원되는 대상: dev, prod, nginx, argocd, k3s, all"
        exit 1
        ;;
esac

echo ""
echo -e "${GREEN}✅ 롤백 작업 완료!${NC}"
echo ""
echo "🔗 권장 후속 작업:"
echo "  ./health-check.sh           # 시스템 상태 확인"
echo "  docker ps                   # Docker 서비스 상태 확인"
echo "  curl http://localhost/      # 웹사이트 접속 테스트"