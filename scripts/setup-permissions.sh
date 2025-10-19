#!/bin/bash
# 스크립트 실행 권한 설정
# 모든 .sh 파일에 실행 권한 부여

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "🔧 스크립트 실행 권한 설정 중..."

chmod +x *.sh

echo "✅ 실행 권한 설정 완료!"
ls -lh *.sh
