# One Day Pub K8s Deployment Scripts 📜

K3s + nginx-ingress + cert-manager + ArgoCD를 사용한 GitOps 배포 자동화 스크립트 모음입니다.

## 📋 스크립트 목록

| 스크립트 | 설명 | 사용 시점 |
|---------|------|---------|
| `deploy.sh` | **통합 배포 스크립트** (추천) | 처음 설치 시 |
| `setup-k3s.sh` | K3s 클러스터 설치 | 개별 설치 시 |
| `install-nginx-ingress.sh` | nginx-ingress-controller 설치 | 개별 설치 시 |
| `install-cert-manager.sh` | cert-manager 설치 | 개별 설치 시 |
| `install-argocd.sh` | ArgoCD 설치 및 설정 | 개별 설치 시 |
| `health-check.sh` | 시스템 상태 모니터링 | 배포 후 |
| `rollback.sh` | 단계별 롤백 | 문제 발생 시 |

## 🚀 빠른 시작 (통합 배포)

### 초기 서버 설정 (1회만)

```bash
# 1. 서버 접속
sshpass -p '3'\''g~]PUg~zx1Bp_z,xwb.-FF_SK27H%R' ssh -p 65522 kws@210.117.237.104

# 2. 프로젝트 클론 (서브모듈 포함)
git clone --recurse-submodules https://github.com/pbc1017/one-day-pub.git
cd one-day-pub/k8s/scripts

# 3. 통합 배포 실행
chmod +x deploy.sh
./deploy.sh

# 4. ArgoCD 초기 비밀번호 확인
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

## 📊 서버 환경

### **서버 정보**
- **IP**: 210.117.237.104
- **사용자**: kws (sudo 권한)
- **SSH 포트**: 65522
- **방화벽**: 65522(SSH), 80(HTTP), 443(HTTPS)

### **배포 환경**
- **개발**: dev.one-day-pub.site (자동 배포)
- **운영**: one-day-pub.site (PR 승인 후 배포)
- **ArgoCD**: argocd.one-day-pub.site (GitOps 관리)

## 🎯 GitOps 배포 흐름

### **아키텍처**
```
GitHub Actions (one-day-pub)
  ↓
Docker Build & Push
  ↓
SSH로 K8s Secrets 생성
  ↓
GitOps 레포 업데이트 (one-day-pub-k8s)
  ↓
ArgoCD 자동 동기화
  ↓
K3s 클러스터 배포
```

### **개발 환경 (dev)**
- **브랜치**: dev
- **도메인**: dev.one-day-pub.site
- **배포**: GitHub Actions → ArgoCD 자동 동기화
- **다운타임**: 최소화 (RollingUpdate)

### **운영 환경 (prod)**
- **브랜치**: main
- **도메인**: one-day-pub.site
- **배포**: GitHub Actions → PR 생성 → 수동 승인 → 배포
- **다운타임**: Zero Downtime

## 🔧 개별 설치 (선택 사항)

순서대로 실행하세요:

```bash
# 1. K3s 클러스터 설치
./setup-k3s.sh

# 2. nginx-ingress-controller 설치
./install-nginx-ingress.sh

# 3. cert-manager 설치
./install-cert-manager.sh

# 4. ArgoCD 설치
./install-argocd.sh

# 5. Root Application 배포
kubectl apply -f ../.argocd/applications/root-app.yaml
```

## 🔐 Secrets 관리

### GitHub Actions 자동 주입 (권장)

GitHub Actions에서 SSH로 서버에 접속하여 자동으로 Secrets를 생성합니다.

**워크플로우**: `.github/workflows/cd-k8s.yml`

**필요한 GitHub Secrets**:
- `DB_USERNAME`, `DB_PASSWORD`
- `MYSQL_ROOT_PASSWORD`
- `JWT_SECRET`, `REFRESH_TOKEN_SECRET`
- `NEXTAUTH_SECRET`
- `TWILIO_ACCOUNT_SID`, `TWILIO_AUTH_TOKEN`, `TWILIO_SERVICE_SID`
- `MAILGUN_API_KEY`, `MAILGUN_DOMAIN`, `MAILGUN_FROM_EMAIL`

### 수동 Secrets 생성 (테스트용)

```bash
# Development
kubectl create secret generic one-day-pub-secrets -n one-day-pub-dev \
  --from-literal=db-username='your_user' \
  --from-literal=db-password='your_pass' \
  --from-literal=mysql-root-password='your_root_pass' \
  --from-literal=jwt-secret='your_jwt_secret' \
  --from-literal=refresh-token-secret='your_refresh_secret' \
  --from-literal=nextauth-secret='your_nextauth_secret' \
  --from-literal=twilio-account-sid='your_twilio_sid' \
  --from-literal=twilio-auth-token='your_twilio_token' \
  --from-literal=twilio-service-sid='your_twilio_service_sid' \
  --from-literal=mailgun-api-key='your_mailgun_key' \
  --from-literal=mailgun-domain='your_mailgun_domain' \
  --from-literal=mailgun-from-email='your_mailgun_email'

# Production (동일한 형식으로 -n one-day-pub-prod)
```

## 🌐 DNS 설정

다음 A 레코드를 DNS 제공자에 추가하세요:

```
argocd.one-day-pub.site  → 210.117.237.104
dev.one-day-pub.site     → 210.117.237.104
one-day-pub.site         → 210.117.237.104
www.one-day-pub.site     → 210.117.237.104
```

## 🔍 상태 확인

### **전체 리소스 확인**
```bash
kubectl get all -A
kubectl get applications -n argocd
kubectl get ingress -A
kubectl get certificates -A
```

### **ArgoCD 애플리케이션 상태**
```bash
kubectl get applications -n argocd
kubectl describe application one-day-pub-dev -n argocd
kubectl describe application one-day-pub-prod -n argocd
```

### **TLS 인증서 확인**
```bash
kubectl get certificates -A
kubectl describe certificate argocd-tls -n argocd
kubectl describe certificate one-day-pub-dev-tls-web -n one-day-pub-dev
kubectl describe certificate one-day-pub-prod-tls-web -n one-day-pub-prod
```

### **Pod 로그 확인**
```bash
# API 로그
kubectl logs -f deployment/one-day-pub-api -n one-day-pub-dev

# Web 로그
kubectl logs -f deployment/one-day-pub-web -n one-day-pub-prod

# ArgoCD 로그
kubectl logs -f deployment/argocd-server -n argocd
```

## 🛡️ 롤백

문제가 발생하면 롤백 스크립트를 사용하세요:

```bash
# 개발환경만 롤백
./rollback.sh dev

# 운영환경만 롤백
./rollback.sh prod

# ArgoCD만 제거
./rollback.sh argocd

# K3s 완전 제거
./rollback.sh k3s

# 전체 롤백
./rollback.sh all
```

## 📝 트러블슈팅

### **K3s 설치 실패**
```bash
# 로그 확인
sudo journalctl -u k3s -f

# 재설치
sudo /usr/local/bin/k3s-uninstall.sh
./setup-k3s.sh
```

### **ArgoCD 접속 불가**
```bash
# 파드 상태 확인
kubectl get pods -n argocd

# Ingress 확인
kubectl get ingress -n argocd
kubectl describe ingress argocd-server-ingress -n argocd

# 비밀번호 재확인
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

### **TLS 인증서 발급 실패**
```bash
# cert-manager 로그 확인
kubectl logs -f deployment/cert-manager -n cert-manager

# Certificate 상태 확인
kubectl describe certificate <cert-name> -n <namespace>

# ClusterIssuer 확인
kubectl get clusterissuer
kubectl describe clusterissuer letsencrypt-prod
```

### **애플리케이션 동기화 실패**
```bash
# ArgoCD 애플리케이션 상태
kubectl get applications -n argocd
kubectl describe application <app-name> -n argocd

# ArgoCD에서 수동 동기화
argocd app sync <app-name>

# ArgoCD 로그
kubectl logs -f deployment/argocd-server -n argocd
```

## 📚 참고 자료

- [K3s 공식 문서](https://docs.k3s.io/)
- [ArgoCD 공식 문서](https://argo-cd.readthedocs.io/)
- [nginx-ingress-controller 문서](https://kubernetes.github.io/ingress-nginx/)
- [cert-manager 문서](https://cert-manager.io/docs/)
- [One Day Pub GitHub](https://github.com/pbc1017/one-day-pub)
- [One Day Pub K8s GitOps 레포](https://github.com/pbc1017/one-day-pub-k8s)

---

⚠️ **주의사항**: 
- 운영환경 배포는 반드시 ArgoCD UI에서 확인 후 수동 승인하세요.
- Secrets는 절대 Git에 커밋하지 마세요. GitHub Actions에서 자동 관리됩니다.

🛡️ **안전 원칙**: 
- 문제 발생 시 즉시 롤백할 수 있도록 준비하세요.
- 배포 전 반드시 헬스체크를 수행하세요.
