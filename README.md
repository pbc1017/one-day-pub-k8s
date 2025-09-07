# KAMF Kubernetes Manifests

K8s 매니페스트, ArgoCD 설정, GitOps 배포 스크립트를 관리하는 레포지토리입니다.

## 📁 구조

```
kamf-k8s/
├── environments/          # 환경별 K8s 매니페스트
│   ├── dev/              # 개발환경 설정
│   └── prod/             # 운영환경 설정
├── base/                 # 기본 K8s 리소스 템플릿
│   ├── api/              # API 서비스 기본 매니페스트
│   ├── web/              # Web 서비스 기본 매니페스트
│   └── mysql/            # MySQL 데이터베이스 매니페스트
├── .argocd/              # ArgoCD 애플리케이션 설정
│   └── applications/     # ArgoCD Application 매니페스트
└── scripts/              # 배포 및 관리 스크립트
```

## 🚀 목적

- **GitOps**: Git 기반 인프라 관리
- **환경 분리**: dev/prod 환경별 설정 관리
- **자동화**: ArgoCD를 통한 자동 배포
- **통합 관리**: 메인 KAMF 프로젝트의 서브모듈로 운영

## 🔗 관련 프로젝트

이 레포지토리는 [KAMF](https://github.com/pbc1017/kamf) 프로젝트의 서브모듈입니다.

## 📋 마이그레이션 계획

Docker Compose → K3s + GitOps + ArgoCD 마이그레이션을 위한 설정들이 포함되어 있습니다.

자세한 내용은 [KAMF-42 이슈](https://www.notion.so/chan1017/k3s-264c0bd47b5d804eb680cf6f3881b96d)를 참조하세요.
