# Daily Tech Digest

백엔드 개발자를 위한 일일 기술 다이제스트.
매일 08:40에 Claude CLI가 자동으로 IT 뉴스, Java, Spring Boot, Database 관련 지식을 정리하고 GitHub에 푸시합니다.

## 다이제스트

매일 자동 생성되는 기술 콘텐츠입니다. 파일명은 `YYYY-MM-DD.md` 형식입니다.

| 카테고리 | 내용 | 항목 수 |
|----------|------|---------|
| [**news/**](news/) | 백엔드, 클라우드, AI 개발 트렌드 뉴스 | 3개/일 |
| [**java/**](java/) | 문법, JVM, 멀티스레딩, 스트림, 최신 버전 기능 | 2개/일 |
| [**springboot/**](springboot/) | DI, AOP, REST API, 시큐리티, 테스트, 성능 최적화 | 2개/일 |
| [**database/**](database/) | SQL, 인덱스, 트랜잭션, 쿼리 최적화, NoSQL | 2개/일 |

## 가이드

주제별로 기본 개념부터 실무 패턴까지 정리한 학습 자료입니다.

### [JPA 핵심 개념](java/jpa/)

| # | 파일 | 내용 |
|---|------|------|
| 01 | [jpa-basics](java/jpa/01-jpa-basics.md) | JPA vs Hibernate vs Spring Data JPA, Entity 매핑 |
| 02 | [entity-lifecycle](java/jpa/02-entity-lifecycle.md) | Entity 4가지 상태, 영속성 컨텍스트 |
| 03 | [dirty-checking](java/jpa/03-dirty-checking.md) | Dirty Checking, Flush |
| 04 | [transactional](java/jpa/04-transactional.md) | @Transactional, readOnly, 프로젝트 패턴 |
| 05 | [association-mapping](java/jpa/05-association-mapping.md) | 연관관계 매핑, 양방향 편의 메서드 |
| 06 | [cascade-orphan](java/jpa/06-cascade-orphan.md) | Cascade, orphanRemoval |
| 07 | [jpql-querydsl](java/jpa/07-jpql-querydsl.md) | JPQL, QueryDSL 동적 쿼리 |
| 08 | [dto-projection](java/jpa/08-dto-projection.md) | DTO Projection, Pageable 페이징 |
| 09 | [n-plus-one](java/jpa/09-n-plus-one.md) | N+1 문제, default_batch_fetch_size |
| 10 | [open-in-view](java/jpa/10-open-in-view.md) | OSIV 설정, LAZY vs EAGER 전략 |
| 11 | [bulk-performance](java/jpa/11-bulk-performance.md) | batch_size, in_clause_parameter_padding |
| 12 | [locking-bulk](java/jpa/12-locking-bulk.md) | @Version 낙관적 락, @Modifying 벌크 연산 |
| 13 | [entity-design](java/jpa/13-entity-design.md) | BaseEntity, AuditorAware, equals/hashCode |
| 14 | [debugging](java/jpa/14-debugging.md) | p6spy, Hibernate 로그 설정 |

## 사용법

```bash
# 수동 실행 (생성 → git add → commit → push)
bash generate.sh

# launchd 즉시 실행
launchctl start com.daekyo.daily-tech-digest

# 실행 로그 확인
cat generate.log
```

## 구조

```
daily-tech-digest/
├── news/           # IT 뉴스 (3개/일)
├── java/           # Java 팁 (2개/일)
│   └── jpa/        # JPA 핵심 개념 가이드 (14개)
├── springboot/     # Spring Boot 팁 (2개/일)
├── database/       # Database 팁 (2개/일)
└── generate.sh     # 다이제스트 자동 생성 스크립트
```
