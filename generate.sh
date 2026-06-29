#!/bin/bash
DATE=$(date +%Y-%m-%d)
MONTH=$(date +%Y-%m)
BASE_DIR="/Users/daekyo/personal/daily-tech-digest"

# 월별 폴더 (카테고리/YYYY-MM/)
NEWS_DIR="$BASE_DIR/news/$MONTH"
JAVA_DIR="$BASE_DIR/java/$MONTH"
SPRING_DIR="$BASE_DIR/springboot/$MONTH"
DB_DIR="$BASE_DIR/database/$MONTH"
ARCH_DIR="$BASE_DIR/architecture/$MONTH"
mkdir -p "$NEWS_DIR" "$JAVA_DIR" "$SPRING_DIR" "$DB_DIR" "$ARCH_DIR"

# Catch-up 가드: 오늘 5개 카테고리 파일이 모두 존재하고 비어있지 않으면 종료 (launchd RunAtLoad 중복 실행 방지)
if [ -s "$NEWS_DIR/${DATE}.md" ] && \
   [ -s "$JAVA_DIR/${DATE}.md" ] && \
   [ -s "$SPRING_DIR/${DATE}.md" ] && \
   [ -s "$DB_DIR/${DATE}.md" ] && \
   [ -s "$ARCH_DIR/${DATE}.md" ]; then
  echo "[$DATE] 이미 생성 완료 — 건너뜀"
  exit 0
fi

# 오늘 날짜 파일이 몇 번째인지 계산 (빈 파일은 이전 실행 실패로 간주하여 덮어쓰기)
get_filename() {
  local dir="$1"
  if [ ! -f "$dir/${DATE}.md" ] || [ ! -s "$dir/${DATE}.md" ]; then
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
# 월 폴더(YYYY-MM)만 대상으로 하여 java/jpa 같은 비날짜 폴더는 자동 제외, 월 경계에서도 직전 달 주제까지 참조
get_recent_topics() {
  local cat_dir="$1"   # 카테고리 루트 (예: $BASE_DIR/java)
  ls -t "$cat_dir"/[0-9][0-9][0-9][0-9]-[0-9][0-9]/*.md 2>/dev/null | head -10 | xargs grep "^### " 2>/dev/null | sed 's/.*### /- /' | sort -u
}

NEWS_FILE=$(get_filename "$NEWS_DIR")
JAVA_FILE=$(get_filename "$JAVA_DIR")
SPRING_FILE=$(get_filename "$SPRING_DIR")
DB_FILE=$(get_filename "$DB_DIR")
ARCH_FILE=$(get_filename "$ARCH_DIR")

RECENT_NEWS=$(get_recent_topics "$BASE_DIR/news")
RECENT_JAVA=$(get_recent_topics "$BASE_DIR/java")
RECENT_SPRING=$(get_recent_topics "$BASE_DIR/springboot")
RECENT_DB=$(get_recent_topics "$BASE_DIR/database")
RECENT_ARCH=$(get_recent_topics "$BASE_DIR/architecture")

# 아키텍처 커리큘럼 단계 자동 결정 — 메인 일일 파일(YYYY-MM-DD.md)만 카운트하여 오늘이 몇 일차인지 계산
ARCH_COUNT=$(ls "$BASE_DIR/architecture"/[0-9][0-9][0-9][0-9]-[0-9][0-9]/[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9].md 2>/dev/null | wc -l | tr -d ' ')
# 오늘 파일이 이미 있으면 그 번째 그대로, 없으면 오늘이 새로 추가될 번째
if [ -s "$ARCH_DIR/${DATE}.md" ]; then
  ARCH_DAY=$ARCH_COUNT
else
  ARCH_DAY=$((ARCH_COUNT + 1))
fi

if [ "$ARCH_DAY" -le 10 ]; then
  ARCH_LEVEL="Lv1 기초 (Day $ARCH_DAY/10)"
  ARCH_SCOPE="단일 서버·모놀리스 기본 패턴 — 레이어드 아키텍처(Controller-Service-Repository), 3-tier, REST API 설계 원칙, DTO/Entity/VO 분리, DI/IoC, 의존성 역전(DIP), 트랜잭션 경계 설계, 세션 vs JWT 인증 구조, 로깅·모니터링 기초, 단일 DB 구조의 장단점"
elif [ "$ARCH_DAY" -le 20 ]; then
  ARCH_LEVEL="Lv2 도메인·계층 설계 (Day $ARCH_DAY)"
  ARCH_SCOPE="DDD(Bounded Context, Aggregate, Entity/VO), Clean Architecture 4계층, Hexagonal/Ports & Adapters, Onion, 도메인 이벤트, CQRS 기본(R/W 분리), 캐싱 전략(Cache-Aside, Write-Through, Write-Behind), API Gateway, BFF(Backend for Frontend), 모듈러 모놀리스"
elif [ "$ARCH_DAY" -le 30 ]; then
  ARCH_LEVEL="Lv3 분산 시스템 (Day $ARCH_DAY)"
  ARCH_SCOPE="모놀리스→MSA 전환(Strangler Fig), 동기 통신(REST/gRPC) vs 비동기(Kafka/RabbitMQ), 이벤트 드리븐 아키텍처, Saga(Choreography vs Orchestration), Event Sourcing, CQRS+ES 조합, Outbox 패턴, 분산 트랜잭션 한계(2PC), API Composition, Idempotency 설계"
elif [ "$ARCH_DAY" -le 40 ]; then
  ARCH_LEVEL="Lv4 클라우드 네이티브·가용성 (Day $ARCH_DAY)"
  ARCH_SCOPE="12-factor app, Kubernetes 기반 배포 패턴, Service Mesh(Istio/Linkerd), Circuit Breaker(Resilience4j), Rate Limiting, Bulkhead, Service Discovery, Load Balancing 전략, Auto Scaling, Multi-region/Active-Active, Observability(Tracing/Metrics/Logging)"
else
  ARCH_LEVEL="Lv5 AI 시대 아키텍처 (Day $ARCH_DAY)"
  ARCH_SCOPE="RAG 아키텍처, Vector DB 통합(Pinecone/Weaviate/pgvector), LLM Gateway 패턴, Agent 시스템(Tool Use/ReAct/Planning), Semantic Cache, Hybrid Search(Vector+Keyword), LLM Routing/Fallback, Multi-Agent Orchestration, MLOps for LLM(Eval/Versioning), AI Observability(LangSmith/LangFuse)"
fi

echo "[$DATE] 다이제스트 생성 시작... ($NEWS_FILE) [아키텍처: $ARCH_LEVEL]"

# IT 뉴스
if [ ! -s "$NEWS_DIR/${DATE}.md" ]; then
claude -p --allowedTools WebSearch <<EOF > "$NEWS_DIR/$NEWS_FILE"
오늘($DATE) 백엔드/서버/클라우드/AI 관련 최신 IT 뉴스 3개를 웹 검색으로 찾아서 한국어 마크다운으로 작성해주세요. AI 개발 도구, LLM API 활용, AI를 활용한 개발 트렌드 포함.

최근에 이미 다룬 주제이므로 반드시 제외해주세요:
${RECENT_NEWS:-없음}

형식:
### 제목
설명 (2-3문장)

> 💡 **왜 중요한가**: 한 문장
EOF
echo "✓ IT 뉴스 완료 → $NEWS_FILE"
else
echo "⊙ IT 뉴스 이미 존재 — 건너뜀"
fi

# Java
if [ ! -s "$JAVA_DIR/${DATE}.md" ]; then
claude -p <<EOF > "$JAVA_DIR/$JAVA_FILE"
오늘($DATE) Java 관련 지식/팁 2개를 한국어 마크다운으로 작성해주세요. Java 문법, JVM, 멀티스레딩, 람다/스트림, 최신 Java 버전 기능 등.

최근에 이미 다룬 주제이므로 반드시 제외해주세요:
${RECENT_JAVA:-없음}

형식:
### 제목
설명 (2-3문장)

> 💡 **왜 중요한가**: 한 문장
EOF
echo "✓ Java 완료 → $JAVA_FILE"
else
echo "⊙ Java 이미 존재 — 건너뜀"
fi

# Spring Boot
if [ ! -s "$SPRING_DIR/${DATE}.md" ]; then
claude -p <<EOF > "$SPRING_DIR/$SPRING_FILE"
오늘($DATE) Spring Boot 관련 지식/팁 2개를 한국어 마크다운으로 작성해주세요. 의존성 주입(DI), AOP, REST API, 시큐리티, 테스트, 성능 최적화 등.

최근에 이미 다룬 주제이므로 반드시 제외해주세요:
${RECENT_SPRING:-없음}

형식:
### 제목
설명 (2-3문장)

> 💡 **왜 중요한가**: 한 문장
EOF
echo "✓ Spring Boot 완료 → $SPRING_FILE"
else
echo "⊙ Spring Boot 이미 존재 — 건너뜀"
fi

# Database
if [ ! -s "$DB_DIR/${DATE}.md" ]; then
claude -p <<EOF > "$DB_DIR/$DB_FILE"
오늘($DATE) Database 관련 지식/팁 2개를 한국어 마크다운으로 작성해주세요. SQL, 인덱스, 트랜잭션, 쿼리 최적화, NoSQL, JPA/Hibernate 등.

최근에 이미 다룬 주제이므로 반드시 제외해주세요:
${RECENT_DB:-없음}

형식:
### 제목
설명 (2-3문장)

> 💡 **왜 중요한가**: 한 문장
EOF
echo "✓ Database 완료 → $DB_FILE"
else
echo "⊙ Database 이미 존재 — 건너뜀"
fi

# 아키텍처 — 커리큘럼 단계에 따라 난이도를 점진적으로 올림
if [ ! -s "$ARCH_DIR/${DATE}.md" ]; then
claude -p <<EOF > "$ARCH_DIR/$ARCH_FILE"
오늘($DATE)은 백엔드 시니어 개발자 아키텍처 학습의 **$ARCH_LEVEL** 단계입니다. 아래 범위 내에서 아직 다루지 않은 주제 1개를 골라 한국어 마크다운으로 깊이 있게 작성해주세요.

이번 단계 학습 범위:
$ARCH_SCOPE

지금까지 누적으로 이미 다룬 주제이므로 반드시 제외해주세요(중복 금지):
${RECENT_ARCH:-없음}

작성 가이드:
- 현재 단계 난이도에 맞춰 설명. 이전 단계(Lv1→Lv2→…) 개념은 독자가 이미 안다고 가정하고 진행. 다음 단계 개념은 아직 다루지 않은 상태로 간주.
- 다이어그램(ASCII 또는 Mermaid) 1개 이상 포함
- 트레이드오프와 실제 사례(어떤 회사/시스템이 왜 이 패턴을 택했는지) 포함
- 시니어 백엔드 관점에서 "언제 쓰고 언제 쓰면 안 되는지" 명확히

형식:
### 제목

본문 (다이어그램·트레이드오프·실제 사례 포함)

> 💡 **왜 중요한가**: 한 문장
EOF
echo "✓ 아키텍처 완료 → $ARCH_FILE ($ARCH_LEVEL)"
else
echo "⊙ 아키텍처 이미 존재 — 건너뜀"
fi

echo "[$DATE] 다이제스트 생성 완료!"

# Git commit & push
cd "$BASE_DIR"
git add .
git commit -m "Daily tech digest - $DATE ($NEWS_FILE)"
git push origin main
echo "[$DATE] GitHub push 완료!"
