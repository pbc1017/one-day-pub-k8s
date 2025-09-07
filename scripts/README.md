# KAMF K8s Deployment Scripts 📜

Phase 6 배포 자동화 스크립트 모음입니다. 실제 서버에 K3s + ArgoCD를 설치하고 Docker → K8s로 점진적으로 마이그레이션할 수 있습니다.

## 📋 스크립트 목록

| 스크립트 | 설명 | 대상 환경 |
|---------|------|---------|
| `setup-k3s.sh` | K3s 클러스터 설치 | 서버 |
| `install-argocd.sh` | ArgoCD 설치 및 설정 | 서버 |
| `switch-dev-immediate.sh` | 개발환경 즉시 K8s 전환 | dev |
| `migrate-nginx.sh` | nginx 점진적 전환 | prod |
| `health-check.sh` | 시스템 상태 모니터링 | 전체 |
| `rollback.sh` | 단계별 롤백 | 전체 |

## 🚀 실행 순서

### **1단계: 기반 인프라 설치**
```bash
# K3s 클러스터 설치
./setup-k3s.sh

# ArgoCD 설치
./install-argocd.sh
```

### **2단계: 개발환경 전환 (즉시)**
```bash
# 개발환경 100% K8s 전환
./switch-dev-immediate.sh

# 상태 확인
./health-check.sh
```

### **3단계: 운영환경 점진적 전환**
```bash
# API 30% K8s 전환
./migrate-nginx.sh kamf_prod_api 30801 30

# Web 30% K8s 전환
./migrate-nginx.sh kamf_prod_web 30901 30

# 1-2일 모니터링 후 70% 전환
./migrate-nginx.sh kamf_prod_api 30801 70
./migrate-nginx.sh kamf_prod_web 30901 70

# 최종 100% 전환
./migrate-nginx.sh kamf_prod_api 30801 100
./migrate-nginx.sh kamf_prod_web 30901 100
```

## 🛡️ 안전장치

### **헬스체크**
```bash
# 시스템 전체 상태 확인
./health-check.sh

# 종료 코드:
# 0: 정상
# 1: 주의사항 있음  
# 2: 심각한 문제 있음
```

### **롤백**
```bash
# 개발환경만 롤백
./rollback.sh dev

# 운영환경만 롤백
./rollback.sh prod

# nginx 설정만 원복
./rollback.sh nginx

# ArgoCD만 제거
./rollback.sh argocd

# K3s 완전 제거
./rollback.sh k3s

# 전체 롤백 (Docker로 완전 복원)
./rollback.sh all
```

## 📊 서버 환경

### **서버 정보**
- **IP**: 210.117.237.104
- **사용자**: kamf (sudo 권한)
- **현재 포트**: 41121(SSH), 80(HTTP), 443(HTTPS)

### **필요한 추가 포트**
```bash
6443/tcp      # Kubernetes API Server
10250/tcp     # Kubelet API
30000-32767/tcp # NodePort Services
```

### **접속 방법**
```bash
# sshpass를 사용한 접속
sshpass -p 'PASSWORD' ssh -p 41121 kamf@210.117.237.104

# 스크립트 실행
cd k8s/scripts
./setup-k3s.sh
```

## 🎯 환경별 전략

### **개발환경 (dev)**
- **전략**: 즉시 100% K8s 전환 ⚡
- **다운타임**: 5-10분 허용
- **장점**: 빠른 검증, 단순한 관리
- **스크립트**: `switch-dev-immediate.sh`

### **운영환경 (prod)**
- **전략**: 점진적 전환 (30% → 70% → 100%) 🛡️
- **다운타임**: Zero Downtime
- **장점**: 안전성, 쉬운 롤백
- **스크립트**: `migrate-nginx.sh`

## 🌐 네트워크 구성

### **NodePort 매핑**
```bash
# 개발환경
dev API:    localhost:30800
dev Web:    localhost:30900  
dev MySQL:  localhost:33307

# 운영환경
prod API:   localhost:30801
prod Web:   localhost:30901
prod MySQL: localhost:33308

# ArgoCD
ArgoCD UI:  localhost:30080 (http://210.117.237.104:30080)
```

### **nginx 업스트림 예시**
```nginx
upstream kamf_prod_api {
    server kamf-api:8000 weight=70;        # Docker 70%
    server 127.0.0.1:30801 weight=30;      # K8s 30%
}
```

## 🔍 모니터링 포인트

### **시스템 리소스**
- 메모리 사용률 < 85%
- 디스크 사용률 < 90%
- CPU 로드 평균 모니터링

### **서비스 상태**
- K8s 파드 Ready 상태
- Docker 컨테이너 Health 상태
- nginx 응답 코드 (2xx, 3xx)

### **응답 시간**
- API 엔드포인트 < 300ms
- 웹사이트 로딩 < 3초
- 에러율 < 5%

## 📝 트러블슈팅

### **자주 발생하는 이슈**

#### **K3s 설치 실패**
```bash
# 로그 확인
sudo journalctl -u k3s -f

# 재설치
sudo /usr/local/bin/k3s-uninstall.sh
./setup-k3s.sh
```

#### **ArgoCD 접속 불가**
```bash
# 파드 상태 확인
kubectl get pods -n argocd

# 비밀번호 재확인
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

#### **nginx 설정 오류**
```bash
# 설정 검증
docker exec kamf-nginx nginx -t

# 백업에서 복원
./rollback.sh nginx
```

#### **K8s 서비스 접근 불가**
```bash
# NodePort 서비스 확인
kubectl get svc -A | grep NodePort

# 파드 로그 확인
kubectl logs -f deployment/kamf-api -n kamf-dev
```

## 📚 참고 자료

- [K3s 공식 문서](https://docs.k3s.io/)
- [ArgoCD 공식 문서](https://argo-cd.readthedocs.io/)
- [Traefik 설정 가이드](https://doc.traefik.io/traefik/)
- [KAMF Phase 6 노션 페이지](https://www.notion.so/chan1017/Phase-6-267c0bd47b5d811b8715eaaa291756a7)

---

⚠️ **주의사항**: 운영환경에서는 반드시 단계적으로 진행하고, 각 단계마다 충분한 모니터링을 수행하세요.

🛡️ **안전 원칙**: 문제 발생 시 즉시 롤백할 수 있도록 준비하고, 백업을 항상 유지하세요.