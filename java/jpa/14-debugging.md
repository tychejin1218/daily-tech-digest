### 1. p6spy — 실행되는 SQL의 실제 파라미터 값 확인하기 (개발 전용)

Hibernate의 `show_sql`은 SQL을 출력하지만 바인딩 파라미터가 `?`로 표시되어 디버깅이 어렵다. p6spy를 사용하면 실제 바인딩된 값이 포함된 완전한 SQL을 로그로 출력하며, 실행 시간까지 함께 표시되어 느린 쿼리를 즉시 파악할 수 있다.

```groovy
// build.gradle — 개발 환경에서만 사용
dependencies {
    implementation 'com.github.gavlyukovskiy:p6spy-spring-boot-starter:1.9.2'
}
```

```yaml
# application-local.yml
spring:
  datasource:
    url: jdbc:p6spy:mysql://localhost:3306/dbank  # jdbc: 뒤에 p6spy: 추가
    driver-class-name: com.p6spy.engine.spy.P6SpyDriver
```

```
Hibernate show_sql (파라미터 안 보임):
  select w from dbank_worksheet w where w.id=? and w.isDeleted=?

p6spy (실제 값 + 실행 시간):
  select w from dbank_worksheet w where w.id=1 and w.isDeleted=false
  -- Execution Time: 3ms
```

```properties
# spy.properties — 포맷 커스터마이징
appender=com.p6spy.engine.spy.appender.Slf4JLogger
logMessageFormat=com.p6spy.engine.spy.appender.CustomLineFormat
customLogMessageFormat=%(executionTime)ms | %(sql)
```

> 💡 **왜 중요한가**: N+1 문제, 불필요한 쿼리, 느린 쿼리를 발견하려면 실제 실행되는 SQL과 파라미터를 확인해야 하며, p6spy는 운영 코드 변경 없이 개발 환경 설정만으로 이를 가능하게 한다. 단, **운영 환경에서는 반드시 제거**해야 한다.

---

### 2. Hibernate 로그 레벨 설정 — p6spy 없이 SQL 디버깅하기

p6spy를 추가하기 어려운 환경에서는 Hibernate 로그 레벨 설정만으로도 실행되는 SQL과 바인딩 파라미터를 확인할 수 있다. `org.hibernate.SQL`은 SQL 문을, `org.hibernate.orm.jdbc.bind`는 바인딩 파라미터 값을 출력한다.

```yaml
# application-local.yml
logging:
  level:
    org.hibernate.SQL: DEBUG                    # 실행되는 SQL 출력
    org.hibernate.orm.jdbc.bind: TRACE          # 바인딩 파라미터 값 출력 (Hibernate 6+)
    # org.hibernate.type.descriptor.sql: TRACE  # Hibernate 5 이하

spring:
  jpa:
    properties:
      hibernate:
        format_sql: true     # SQL 포맷팅 (줄바꿈, 들여쓰기)
        use_sql_comments: true  # JPQL 원본을 주석으로 표시
```

```
출력 예시:

/* select w from DbankWorksheet w where w.id = :id */ ← use_sql_comments
select                     ← format_sql
    w.id,
    w.worksheet_name,
    w.is_deleted
from
    dbank_worksheet w
where
    w.id=?

binding parameter (1:BIGINT) <- [1]     ← org.hibernate.orm.jdbc.bind
```

**로그 레벨별 정보:**

| 로거 | 레벨 | 출력 내용 |
|------|------|----------|
| `org.hibernate.SQL` | DEBUG | 실행되는 SQL |
| `org.hibernate.orm.jdbc.bind` | TRACE | 바인딩 파라미터 값 |
| `org.hibernate.stat` | DEBUG | 세션 통계 (쿼리 수, 캐시 적중률) |

```yaml
# 쿼리 수 확인용 — N+1 감지에 유용
spring:
  jpa:
    properties:
      hibernate:
        generate_statistics: true  # 트랜잭션당 쿼리 수 통계

logging:
  level:
    org.hibernate.stat: DEBUG
# 출력: Session Metrics { 23 nanoseconds spent acquiring 1 JDBC connections; ... 12 JDBC statements executed; }
```

> 💡 **왜 중요한가**: `generate_statistics`를 켜면 트랜잭션당 실행된 쿼리 수를 확인할 수 있어 N+1 문제를 숫자로 즉시 감지할 수 있고, 바인딩 파라미터 로그는 잘못된 조건이나 NULL 전달 같은 논리 오류를 빠르게 찾아낼 수 있다.