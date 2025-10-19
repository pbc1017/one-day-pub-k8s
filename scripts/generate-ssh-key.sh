#!/bin/bash
# GitHub Actions용 SSH 키 생성 스크립트

set -e

echo "🔑 GitHub Actions용 SSH 키 생성..."

# SSH 디렉터리 확인
SSH_DIR="$HOME/.ssh"
KEY_NAME="github-actions-deploy"
KEY_PATH="$SSH_DIR/$KEY_NAME"

if [ ! -d "$SSH_DIR" ]; then
    mkdir -p "$SSH_DIR"
    chmod 700 "$SSH_DIR"
fi

# 이미 키가 있는지 확인
if [ -f "$KEY_PATH" ]; then
    echo "⚠️  SSH 키가 이미 존재합니다: $KEY_PATH"
    read -p "새로 생성하시겠습니까? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "기존 키를 사용합니다."
        cat "$KEY_PATH.pub"
        exit 0
    fi
    rm -f "$KEY_PATH" "$KEY_PATH.pub"
fi

# SSH 키 생성 (ed25519 알고리즘, 빠르고 안전)
echo "📝 SSH 키 생성 중..."
ssh-keygen -t ed25519 -C "github-actions@one-day-pub" -f "$KEY_PATH" -N ""

# 공개 키를 authorized_keys에 추가
echo "🔐 공개 키를 authorized_keys에 추가..."
cat "$KEY_PATH.pub" >> "$SSH_DIR/authorized_keys"
chmod 600 "$SSH_DIR/authorized_keys"

echo ""
echo "✅ SSH 키 생성 완료!"
echo ""
echo "📋 GitHub Secrets에 추가할 정보:"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "SECRET: SERVER_SSH_KEY"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
cat "$KEY_PATH"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📌 추가 정보:"
echo "  SERVER_HOST: 210.117.237.104"
echo "  SERVER_USERNAME: kws"
echo "  SERVER_PORT: 65522"
echo ""
echo "🔗 GitHub에서 설정:"
echo "  1. https://github.com/pbc1017/one-day-pub/settings/secrets/actions"
echo "  2. 'New repository secret' 클릭"
echo "  3. Name: SERVER_SSH_KEY"
echo "  4. Value: 위의 개인 키 전체 내용 복사 (-----BEGIN ... END----- 포함)"
echo "  5. 'Add secret' 클릭"
echo ""
echo "⚠️  보안 주의사항:"
echo "  - 개인 키는 절대 GitHub 레포지토리에 커밋하지 마세요"
echo "  - 개인 키는 반드시 GitHub Secrets에만 저장하세요"
echo "  - 이 키는 서버에만 보관되어야 합니다"
echo ""
