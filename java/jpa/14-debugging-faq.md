### Q1. `show_sql`만 켜도 되는데 굳이 p6spy를 쓰는 이유가 뭔가요?

`show_sql`은 파라미터가 `?`로 가려져 "어떤 값으로 실행됐는지"를 알 수 없다. p6spy는 **바인딩된 실제 값이 채워진 완성된 SQL**과 **실행 시간**까지 찍어줘서, 잘못된 조건이나 느린 쿼리를 바로 짚어낼 수 있다. 디버깅 효율이 크게 다르다.

```
show_sql : where w.id=? and w.is_deleted=?
p6spy    : where w.id=1 and w.is_deleted=false   -- 3ms
```

> 💡 **정리**: show_sql은 ?로 가려진다. p6spy는 실제 값+실행시간까지 보여준다.

---

### Q2. p6spy를 운영에도 그냥 두면 안 되나요?

안 된다. p6spy는 모든 쿼리를 가로채 문자열을 조립·로깅하므로 **오버헤드**가 있고, 무엇보다 바인딩 값(개인정보 등)이 그대로 로그에 남아 **보안 문제**가 된다. 개발/로컬 프로파일에서만 의존성을 넣고, 운영 빌드에서는 제거하는 게 원칙이다.

> 💡 **정리**: p6spy는 오버헤드+민감정보 로깅 위험 → 개발 전용, 운영엔 제거.

---

### Q3. p6spy를 못 넣는 환경에서 바인딩 파라미터를 보려면?

Hibernate 로그 레벨만으로 가능하다. `org.hibernate.SQL=DEBUG`로 SQL을, `org.hibernate.orm.jdbc.bind=TRACE`로 바인딩 값을 출력한다. `format_sql`, `use_sql_comments`까지 켜면 줄바꿈된 SQL과 원본 JPQL 주석도 같이 본다.

```yaml
logging.level.org.hibernate.SQL: DEBUG
logging.level.org.hibernate.orm.jdbc.bind: TRACE   # Hibernate 6+
```

> 💡 **정리**: org.hibernate.SQL(DEBUG) + org.hibernate.orm.jdbc.bind(TRACE)면 의존성 없이 값까지 본다.

---

### Q4. N+1이 발생하는지 "쿼리 수"로 확인하려면 어떻게 하나요?

`generate_statistics`를 켜면 트랜잭션마다 실행된 JDBC statement 수를 로그로 찍어준다. 한 요청에서 statement 수가 데이터 건수에 비례해 늘면 N+1이다. 눈으로 SQL을 세지 않고 숫자로 바로 판별할 수 있다.

```yaml
spring.jpa.properties.hibernate.generate_statistics: true
logging.level.org.hibernate.stat: DEBUG
# → "12 JDBC statements executed" 식으로 출력
```

> 💡 **정리**: generate_statistics로 트랜잭션당 쿼리 수를 찍어 N+1을 숫자로 잡는다.

---

### Q5. 예전 자료의 바인딩 로거 설정이 안 먹어요. 뭐가 바뀐 건가요?

Hibernate 버전에 따라 바인딩 파라미터 로거 이름이 다르다. **Hibernate 6+**는 `org.hibernate.orm.jdbc.bind`이고, **Hibernate 5 이하**는 `org.hibernate.type.descriptor.sql`이었다. Spring Boot 3는 Hibernate 6를 쓰므로 새 로거 이름을 써야 파라미터가 찍힌다.

```yaml
# Spring Boot 3 / Hibernate 6
logging.level.org.hibernate.orm.jdbc.bind: TRACE
# (구버전) logging.level.org.hibernate.type.descriptor.sql: TRACE
```

> 💡 **정리**: Hibernate 6는 org.hibernate.orm.jdbc.bind. 옛 로거 이름은 안 먹는다.
