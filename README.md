# daily-tech-digest

백엔드 개발자를 위한 AI 기반 일일 기술 다이제스트. Claude CLI를 활용해 매일 최신 IT 뉴스, Java, Spring Boot, Database 관련 지식을 자동으로 수집·정리하고 GitHub에 커밋합니다.

## 구조

```
daily-tech-digest/
├── news/           # 백엔드/클라우드/AI 최신 IT 뉴스 (3개/일)
├── java/           # Java 지식 및 팁 (2개/일)
├── springboot/     # Spring Boot 지식 및 팁 (2개/일)
├── database/       # Database 지식 및 팁 (2개/일)
└── generate.sh     # 다이제스트 자동 생성 스크립트
```

## 콘텐츠 카테고리

| 카테고리 | 내용 |
|----------|------|
| **IT 뉴스** | 백엔드, 서버, 클라우드, AI 개발 트렌드 뉴스 |
| **Java** | 문법, JVM, 멀티스레딩, 람다/스트림, 최신 버전 기능 |
| **Spring Boot** | DI, AOP, REST API, 시큐리티, 테스트, 성능 최적화 |
| **Database** | SQL, 인덱스, 트랜잭션, 쿼리 최적화, NoSQL, JPA/Hibernate |

## 사용법

### 수동 실행

```bash
chmod +x generate.sh
./generate.sh
```

스크립트 실행 시 오늘 날짜(`YYYY-MM-DD`) 파일이 각 카테고리 폴더에 생성되고, 자동으로 GitHub에 커밋 및 푸시됩니다.

### 자동화 (cron)

매일 특정 시간에 자동 실행하려면 crontab에 등록합니다.

```bash
crontab -e
```

```cron
# 매일 오전 8시에 실행
0 8 * * * /Users/daekyo/personal/daily-tech-digest/generate.sh >> /tmp/daily-digest.log 2>&1
```

## 의존성

- [Claude CLI](https://github.com/anthropics/claude-code) — 콘텐츠 생성에 사용
- Git — 자동 커밋 및 푸시
