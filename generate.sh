#!/bin/bash
DATE=$(date +%Y-%m-%d)
BASE_DIR="/Users/daekyo/personal/daily-tech-digest"

mkdir -p "$BASE_DIR/news" "$BASE_DIR/java" "$BASE_DIR/springboot" "$BASE_DIR/database"

# 오늘 날짜 파일이 몇 번째인지 계산
get_filename() {
  local dir="$1"
  if [ ! -f "$dir/${DATE}.md" ]; then
    echo "${DATE}.md"
    return
  fi
  local num=2
  while [ -f "$dir/${DATE}($num).md" ]; do
    num=$((num + 1))
  done
  echo "${DATE}($num).md"
}

# 최근 파일들에서 다룬 주제 제목 추출 (중복 방지용)
get_recent_topics() {
  local dir="$1"
  ls -t "$dir"/*.md 2>/dev/null | head -10 | xargs grep "^### " 2>/dev/null | sed 's/.*### /- /' | sort -u
}

NEWS_FILE=$(get_filename "$BASE_DIR/news")
JAVA_FILE=$(get_filename "$BASE_DIR/java")
SPRING_FILE=$(get_filename "$BASE_DIR/springboot")
DB_FILE=$(get_filename "$BASE_DIR/database")

RECENT_NEWS=$(get_recent_topics "$BASE_DIR/news")
RECENT_JAVA=$(get_recent_topics "$BASE_DIR/java")
RECENT_SPRING=$(get_recent_topics "$BASE_DIR/springboot")
RECENT_DB=$(get_recent_topics "$BASE_DIR/database")

echo "[$DATE] 다이제스트 생성 시작... ($NEWS_FILE)"

# IT 뉴스
claude -p "오늘($DATE) 백엔드/서버/클라우드/AI 관련 최신 IT 뉴스 3개를 한국어 마크다운으로 작성해주세요. AI 개발 도구, LLM API 활용, AI를 활용한 개발 트렌드 포함.

최근에 이미 다룬 주제이므로 반드시 제외해주세요:
${RECENT_NEWS:-없음}

형식:
### 제목
설명 (2-3문장)

> 💡 **왜 중요한가**: 한 문장" > "$BASE_DIR/news/$NEWS_FILE"
echo "✓ IT 뉴스 완료 → $NEWS_FILE"

# Java
claude -p "오늘($DATE) Java 관련 지식/팁 2개를 한국어 마크다운으로 작성해주세요. Java 문법, JVM, 멀티스레딩, 람다/스트림, 최신 Java 버전 기능 등.

최근에 이미 다룬 주제이므로 반드시 제외해주세요:
${RECENT_JAVA:-없음}

형식:
### 제목
설명 (2-3문장)

> 💡 **왜 중요한가**: 한 문장" > "$BASE_DIR/java/$JAVA_FILE"
echo "✓ Java 완료 → $JAVA_FILE"

# Spring Boot
claude -p "오늘($DATE) Spring Boot 관련 지식/팁 2개를 한국어 마크다운으로 작성해주세요. 의존성 주입(DI), AOP, REST API, 시큐리티, 테스트, 성능 최적화 등.

최근에 이미 다룬 주제이므로 반드시 제외해주세요:
${RECENT_SPRING:-없음}

형식:
### 제목
설명 (2-3문장)

> 💡 **왜 중요한가**: 한 문장" > "$BASE_DIR/springboot/$SPRING_FILE"
echo "✓ Spring Boot 완료 → $SPRING_FILE"

# Database
claude -p "오늘($DATE) Database 관련 지식/팁 2개를 한국어 마크다운으로 작성해주세요. SQL, 인덱스, 트랜잭션, 쿼리 최적화, NoSQL, JPA/Hibernate 등.

최근에 이미 다룬 주제이므로 반드시 제외해주세요:
${RECENT_DB:-없음}

형식:
### 제목
설명 (2-3문장)

> 💡 **왜 중요한가**: 한 문장" > "$BASE_DIR/database/$DB_FILE"
echo "✓ Database 완료 → $DB_FILE"

echo "[$DATE] 다이제스트 생성 완료!"

# Git commit & push
cd "$BASE_DIR"
git add .
git commit -m "Daily tech digest - $DATE ($NEWS_FILE)"
git push origin main
echo "[$DATE] GitHub push 완료!"
