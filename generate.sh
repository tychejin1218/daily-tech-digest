#!/bin/bash
DATE=$(date +%Y-%m-%d)
BASE_DIR="/Users/daekyo/personal/daily-tech-digest"

mkdir -p "$BASE_DIR/news" "$BASE_DIR/java" "$BASE_DIR/springboot" "$BASE_DIR/database"

echo "[$DATE] 다이제스트 생성 시작..."

# IT 뉴스
claude -p "오늘($DATE) 백엔드/서버/클라우드/AI 관련 최신 IT 뉴스 3개를 한국어 마크다운으로 작성해주세요. AI 개발 도구, LLM API 활용, AI를 활용한 개발 트렌드 포함.\n\n# IT 뉴스 - $DATE\n\n형식:\n### 제목\n설명 (2-3문장)\n\n> 💡 **왜 중요한가**: 한 문장" > "$BASE_DIR/news/$DATE.md"
echo "✓ IT 뉴스 완료"

# Java
claude -p "오늘($DATE) Java 관련 지식/팁 2개를 한국어 마크다운으로 작성해주세요. Java 문법, JVM, 멀티스레딩, 람다/스트림, 최신 Java 버전 기능 등.\n\n# Java - $DATE\n\n형식:\n### 제목\n설명 (2-3문장)\n\n> 💡 **왜 중요한가**: 한 문장" > "$BASE_DIR/java/$DATE.md"
echo "✓ Java 완료"

# Spring Boot
claude -p "오늘($DATE) Spring Boot 관련 지식/팁 2개를 한국어 마크다운으로 작성해주세요. 의존성 주입(DI), AOP, REST API, 시큐리티, 테스트, 성능 최적화 등.\n\n# Spring Boot - $DATE\n\n형식:\n### 제목\n설명 (2-3문장)\n\n> 💡 **왜 중요한가**: 한 문장" > "$BASE_DIR/springboot/$DATE.md"
echo "✓ Spring Boot 완료"

# Database
claude -p "오늘($DATE) Database 관련 지식/팁 2개를 한국어 마크다운으로 작성해주세요. SQL, 인덱스, 트랜잭션, 쿼리 최적화, NoSQL, JPA/Hibernate 등.\n\n# Database - $DATE\n\n형식:\n### 제목\n설명 (2-3문장)\n\n> 💡 **왜 중요한가**: 한 문장" > "$BASE_DIR/database/$DATE.md"
echo "✓ Database 완료"

echo "[$DATE] 다이제스트 생성 완료!"

# Git commit & push
cd "$BASE_DIR"
git add .
git commit -m "Daily tech digest - $DATE"
git push origin main
echo "[$DATE] GitHub push 완료!"
