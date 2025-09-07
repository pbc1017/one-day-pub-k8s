#!/bin/bash
# nginx upstream 점진적 전환 스크립트
# Phase 6: 운영환경 점진적 마이그레이션 (Zero Downtime)

set -e

# 사용법 체크
if [ $# -lt 3 ]; then
    echo "사용법: $0 <서비스명> <K8s_NodePort> <K8s_비율>"
    echo ""
    echo "예시:"
    echo "  $0 kamf_prod_api 30801 30    # API 30% K8s 전환"
    echo "  $0 kamf_prod_web 30901 70    # Web 70% K8s 전환"
    echo "  $0 kamf_prod_api 30801 100   # API 100% K8s 전환"
    echo ""
    echo "지원되는 서비스:"
    echo "  - kamf_prod_api (운영 API)"
    echo "  - kamf_prod_web (운영 Web)"
    exit 1
fi

SERVICE_NAME=$1
K8S_NODEPORT=$2
K8S_WEIGHT=$3

# 입력값 검증
if [[ ! "$SERVICE_NAME" =~ ^kamf_prod_(api|web)$ ]]; then
    echo "❌ 잘못된 서비스명: $SERVICE_NAME"
    echo "지원되는 서비스: kamf_prod_api, kamf_prod_web"
    exit 1
fi

if [[ ! "$K8S_WEIGHT" =~ ^[0-9]+$ ]] || [ "$K8S_WEIGHT" -lt 0 ] || [ "$K8S_WEIGHT" -gt 100 ]; then
    echo "❌ K8s 비율은 0-100 사이의 숫자여야 합니다: $K8S_WEIGHT"
    exit 1
fi

DOCKER_WEIGHT=$((100 - K8S_WEIGHT))

echo "🔄 $SERVICE_NAME 점진적 전환 시작..."
echo "📊 전환 비율: Docker ${DOCKER_WEIGHT}% ← → K8s ${K8S_WEIGHT}%"

# Docker 서비스 포트 매핑
case $SERVICE_NAME in
    "kamf_prod_api")
        DOCKER_SERVICE="kamf-api"
        DOCKER_PORT="8000"
        ;;
    "kamf_prod_web")
        DOCKER_SERVICE="kamf-web"
        DOCKER_PORT="3000"
        ;;
esac

echo "🎯 대상 서비스: $DOCKER_SERVICE (Docker:$DOCKER_PORT → K8s:$K8S_NODEPORT)"

# nginx 컨테이너 존재 확인
if ! docker ps | grep -q "kamf-nginx"; then
    echo "❌ kamf-nginx 컨테이너를 찾을 수 없습니다."
    exit 1
fi

# K8s NodePort 서비스 존재 확인
if ! curl -f "http://localhost:$K8S_NODEPORT/health" >/dev/null 2>&1; then
    echo "⚠️  K8s NodePort 서비스 응답 없음 (포트: $K8S_NODEPORT)"
    echo "   K8s 서비스가 실행 중인지 확인하세요."
fi

# Docker 서비스 존재 확인  
if [ "$DOCKER_WEIGHT" -gt 0 ] && ! docker ps | grep -q "$DOCKER_SERVICE"; then
    echo "⚠️  Docker 서비스가 실행 중이지 않음: $DOCKER_SERVICE"
    echo "   Docker 서비스를 시작하거나 K8s 100% 전환을 고려하세요."
fi

# nginx upstream 설정 생성
echo "⚙️  nginx upstream 설정 생성..."
cat > /tmp/upstream_${SERVICE_NAME}.conf << EOF
# $SERVICE_NAME upstream configuration
# Generated at: $(date)
# Docker: ${DOCKER_WEIGHT}%, K8s: ${K8S_WEIGHT}%

upstream $SERVICE_NAME {
    least_conn;  # 연결 수 기반 로드밸런싱
EOF

# Docker 서비스 추가 (가중치 0이 아닌 경우)
if [ "$DOCKER_WEIGHT" -gt 0 ]; then
    echo "    server ${DOCKER_SERVICE}:${DOCKER_PORT} weight=${DOCKER_WEIGHT} max_fails=3 fail_timeout=30s;" >> /tmp/upstream_${SERVICE_NAME}.conf
fi

# K8s 서비스 추가 (가중치 0이 아닌 경우)
if [ "$K8S_WEIGHT" -gt 0 ]; then
    echo "    server 127.0.0.1:${K8S_NODEPORT} weight=${K8S_WEIGHT} max_fails=3 fail_timeout=30s;" >> /tmp/upstream_${SERVICE_NAME}.conf
fi

cat >> /tmp/upstream_${SERVICE_NAME}.conf << EOF
}
EOF

echo "📄 생성된 upstream 설정:"
cat /tmp/upstream_${SERVICE_NAME}.conf

# nginx 설정 백업
echo "💾 현재 nginx 설정 백업..."
docker exec kamf-nginx cp /etc/nginx/conf.d/kamf-common.conf /etc/nginx/conf.d/kamf-common.conf.backup.$(date +%Y%m%d_%H%M%S)

# nginx 설정 파일에 upstream 설정 업데이트
echo "🔧 nginx 설정 업데이트..."

# 기존 upstream 블록 제거하고 새로운 설정 추가
docker exec kamf-nginx bash -c "
    # 기존 upstream $SERVICE_NAME 블록 제거
    sed '/^upstream $SERVICE_NAME/,/^}/d' /etc/nginx/conf.d/kamf-common.conf > /tmp/new_config
    
    # 새로운 upstream 설정을 파일 맨 앞에 추가
    cat /tmp/new_config > /etc/nginx/conf.d/kamf-common.conf.new
    mv /etc/nginx/conf.d/kamf-common.conf.new /etc/nginx/conf.d/kamf-common.conf
"

# 새로운 upstream 설정을 nginx 컨테이너에 복사
docker cp /tmp/upstream_${SERVICE_NAME}.conf kamf-nginx:/tmp/upstream_${SERVICE_NAME}.conf

# nginx 설정 파일 앞쪽에 upstream 설정 추가
docker exec kamf-nginx bash -c "
    cat /tmp/upstream_${SERVICE_NAME}.conf /etc/nginx/conf.d/kamf-common.conf > /tmp/combined_config
    mv /tmp/combined_config /etc/nginx/conf.d/kamf-common.conf
"

# nginx 설정 문법 검사
echo "🔍 nginx 설정 문법 검사..."
if ! docker exec kamf-nginx nginx -t; then
    echo "❌ nginx 설정 오류! 백업에서 복원합니다..."
    docker exec kamf-nginx bash -c "cp /etc/nginx/conf.d/kamf-common.conf.backup.* /etc/nginx/conf.d/kamf-common.conf"
    exit 1
fi

# nginx 설정 리로드
echo "🔄 nginx 설정 리로드..."
docker exec kamf-nginx nginx -s reload

# 임시 파일 정리
rm -f /tmp/upstream_${SERVICE_NAME}.conf

# 전환 후 헬스체크
echo "🏥 전환 후 헬스체크..."
sleep 5

# 서비스별 헬스체크 URL 설정
case $SERVICE_NAME in
    "kamf_prod_api")
        HEALTH_URL="https://kamf.site/api/health"
        ;;
    "kamf_prod_web")
        HEALTH_URL="https://kamf.site/"
        ;;
esac

# 헬스체크 실행
echo "🌐 서비스 헬스체크: $HEALTH_URL"
if curl -f -s "$HEALTH_URL" >/dev/null; then
    echo "✅ $SERVICE_NAME 헬스체크 성공"
else
    echo "⚠️  $SERVICE_NAME 헬스체크 실패"
    echo "   수동으로 서비스 상태를 확인하세요."
fi

# 로드밸런싱 테스트
echo "🔀 로드밸런싱 테스트 (5회 요청)..."
for i in {1..5}; do
    RESPONSE=$(curl -s -w "%{http_code}" -o /dev/null "$HEALTH_URL" || echo "000")
    echo "  요청 $i: HTTP $RESPONSE"
done

echo ""
echo "🎉 $SERVICE_NAME 전환 완료!"
echo ""
echo "📊 현재 설정:"
echo "- Docker ($DOCKER_SERVICE): ${DOCKER_WEIGHT}%"
echo "- K8s (NodePort $K8S_NODEPORT): ${K8S_WEIGHT}%"
echo ""
echo "🔗 다음 단계:"
if [ "$K8S_WEIGHT" -lt 100 ]; then
    echo "  1. 1-2일간 모니터링"
    echo "  2. 이상 없으면 더 높은 비율로 전환:"
    echo "     $0 $SERVICE_NAME $K8S_NODEPORT $((K8S_WEIGHT + 30))"
else
    echo "  1. K8s 100% 전환 완료!"
    echo "  2. Docker 서비스 중단 가능:"
    echo "     docker stop $DOCKER_SERVICE"
fi
echo ""
echo "📝 유용한 명령어:"
echo "  docker exec kamf-nginx cat /etc/nginx/conf.d/kamf-common.conf  # 설정 확인"
echo "  docker exec kamf-nginx nginx -s reload                         # 수동 리로드"
echo "  ./rollback.sh nginx                                            # nginx 설정 롤백"