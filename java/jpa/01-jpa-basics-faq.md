### Q1. 면접에서 "JPA와 Hibernate 차이"를 물으면 어떻게 답해야 하나요?

JPA는 자바 ORM의 **표준 스펙(인터페이스 모음)**이고, Hibernate는 그 스펙을 실제로 구현한 **구현체**다. 우리가 `@Entity`, `EntityManager`를 쓰는 건 JPA 스펙이고, 실제 SQL 생성·Dirty Checking·캐시 동작은 Hibernate가 한다. Spring Data JPA는 그 위에서 `Repository` 패턴을 얹은 추상화 계층이다.

```java
worksheetRepository.save(entity);   // Spring Data JPA
// → em.persist(entity)             // JPA 표준 API
// → INSERT INTO ...                // Hibernate가 SQL 생성 → JDBC
```

> 💡 **정리**: "JPA=규약, Hibernate=구현, Spring Data JPA=편의 추상화" 세 줄이면 충분하다.

---

### Q2. `@GeneratedValue(IDENTITY)`를 쓰면 왜 대량 INSERT 성능이 떨어지나요?

IDENTITY는 DB의 AUTO_INCREMENT로 PK를 만들기 때문에, ID 값을 알려면 INSERT를 실제로 실행해야 한다. 그래서 `save()` 호출 즉시 INSERT가 나가고, 여러 건을 모아 한 번에 보내는 **쓰기 지연(batch insert)**이 불가능하다. 수천 건을 넣어야 하면 JDBC batch나 `jdbcTemplate.batchUpdate()`를 따로 써야 한다.

```java
worksheetRepository.save(ws);   // IDENTITY → 이 줄에서 즉시 INSERT 실행
System.out.println(ws.getId()); // DB가 방금 할당한 PK가 바로 채워짐
```

> 💡 **정리**: MySQL+IDENTITY는 건건이 INSERT가 나가므로, bulk insert가 필요하면 JPA 밖의 batch를 고려한다.

---

### Q3. Entity 필드명과 컬럼명이 다른데 `@Column`을 안 써도 동작하던데, 왜죠?

Spring Boot + Hibernate는 기본적으로 `CamelCaseToUnderscoresNamingStrategy`로 camelCase 필드를 snake_case 컬럼으로 자동 매핑한다. 그래서 `worksheetName` 필드는 `worksheet_name` 컬럼으로 알아서 연결된다. 다만 테이블명이 클래스명과 다르거나(`@Table`), 길이·null 제약을 드러내고 싶을 때(`@Column`)는 명시하는 게 의도가 분명하다.

```java
private String worksheetName;             // → worksheet_name (자동 변환)

@Column(name = "worksheet_name", nullable = false, length = 200)
private String worksheetName;             // 명시 — 의도가 드러남
```

> 💡 **정리**: 이름 매핑은 네이밍 전략이 자동 처리하지만, 제약·의도 표현이 필요하면 명시한다.

---

### Q4. `@Column(nullable = false)`나 `length`는 실제 DB에 제약을 거나요?

이 속성들이 DB에 반영되는지는 `spring.jpa.hibernate.ddl-auto` 설정에 달려 있다. `create`/`update`면 Hibernate가 그 정보로 DDL을 생성하지만, 운영에서 흔히 쓰는 `validate`/`none`이면 DDL을 만들지 않으므로 실제 제약은 DB 스키마에 직접 걸어야 한다. 즉 `nullable = false`는 "보장"이 아니라 매핑 메타데이터일 뿐이다.

```yaml
spring:
  jpa:
    hibernate:
      ddl-auto: validate   # 운영 권장: 스키마 검증만, 변경 안 함
```

> 💡 **정리**: 운영은 보통 validate/none이라 @Column 제약이 DDL을 만들지 않으니, 실제 제약은 DB에 둬야 한다.

---

### Q5. Repository만 쓰면 되는데 `EntityManager`를 직접 쓸 일이 있나요?

대부분은 `JpaRepository`로 충분하지만, 표준 메서드로 표현하기 어려운 동적 쿼리·벌크 연산이나 `em.flush()`/`em.clear()` 같은 영속성 컨텍스트 직접 제어가 필요할 때 `EntityManager`를 쓴다. 이 프로젝트의 QueryDSL `JPAQueryFactory`도 내부적으로 `EntityManager`를 주입받아 동작한다.

```java
@PersistenceContext
private EntityManager em;

// 대량 처리 중 메모리 관리
em.flush();
em.clear();   // 1차 캐시 비워 OutOfMemory 방지
```

> 💡 **정리**: 일상은 Repository, 영속성 컨텍스트를 직접 다뤄야 할 때만 EntityManager로 내려간다.
