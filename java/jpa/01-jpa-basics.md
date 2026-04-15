### 1. JPA vs Hibernate vs Spring Data JPA — 각각의 역할과 관계

JPA(Java Persistence API)는 ORM의 **표준 스펙(인터페이스)**이고, Hibernate는 그 스펙을 구현한 **구현체**다. Spring Data JPA는 Hibernate 위에서 `Repository` 패턴을 제공하는 **추상화 계층**으로, 이 세 가지가 계층 구조를 이룬다.

```
┌─────────────────────────────────────────┐
│          Spring Data JPA                │  ← Repository 인터페이스, 쿼리 메서드
│  (JpaRepository, @Query, Pageable)      │
├─────────────────────────────────────────┤
│            Hibernate                    │  ← JPA 구현체 (SQL 생성, 캐시, Dirty Checking)
│  (SessionFactory, HQL, 2차 캐시)         │
├─────────────────────────────────────────┤
│              JPA                        │  ← 표준 스펙 (인터페이스)
│  (EntityManager, JPQL, @Entity)         │
├─────────────────────────────────────────┤
│             JDBC                        │  ← DB 드라이버
└─────────────────────────────────────────┘
```

```java
// JPA 표준 API — EntityManager 직접 사용
@PersistenceContext
private EntityManager em;

em.persist(entity);                    // INSERT
em.find(DbankWorksheet.class, 1L);     // SELECT by ID
em.createQuery("SELECT w FROM DbankWorksheet w", DbankWorksheet.class);  // JPQL

// Spring Data JPA — Repository 인터페이스로 추상화
public interface WorksheetRepository extends JpaRepository<DbankWorksheet, Long> {
    // 메서드 이름만으로 쿼리 자동 생성
    List<DbankWorksheet> findByIsDeletedFalse();
}

// 내부적으로 Spring Data JPA → Hibernate → JDBC 순서로 호출됨
worksheetRepository.save(entity);
// → Hibernate: em.persist(entity)
// → JDBC: INSERT INTO dbank_worksheet (...) VALUES (...)
```

> 💡 **왜 중요한가**: JPA는 스펙이고 Hibernate는 구현체라는 관계를 이해해야, 에러 메시지가 Hibernate에서 나올 때 당황하지 않고 올바른 문서를 찾아 해결할 수 있다.

---

### 2. Entity 매핑 기본 — @Entity, @Table, @Column, @Id, @GeneratedValue

JPA Entity는 DB 테이블과 1:1로 매핑되며, `@Entity`로 선언하고 `@Id`로 기본 키를 지정한다. 클래스명과 테이블명이 다르면 `@Table`, 필드명과 컬럼명이 다르면 `@Column`으로 명시적 매핑한다. Spring Boot + Hibernate는 기본적으로 camelCase → snake_case 자동 변환을 지원한다.

```java
@Entity
@Table(name = "dbank_worksheet")  // 클래스명과 테이블명이 다를 때
public class DbankWorksheet extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)  // MySQL AUTO_INCREMENT
    private Long id;

    @Column(name = "worksheet_name", nullable = false, length = 200)
    private String worksheetName;
    // camelCase → snake_case 자동 변환이므로 @Column 생략 가능
    // 명시적으로 쓰면 의도가 더 명확함

    @Column(columnDefinition = "TINYINT(1) DEFAULT 0")
    private Boolean isDeleted = false;

    @Column(updatable = false)  // UPDATE 시 이 컬럼 제외
    private LocalDateTime createdAt;
}
```

**@GeneratedValue 전략:**

| 전략 | 설명 | 주로 사용하는 DB |
|------|------|----------------|
| `IDENTITY` | DB의 AUTO_INCREMENT 사용 | MySQL |
| `SEQUENCE` | DB 시퀀스 사용 | PostgreSQL, Oracle |
| `TABLE` | 키 생성 전용 테이블 사용 | 범용 (비권장) |
| `AUTO` | DB에 맞게 자동 선택 | - |

```java
// IDENTITY 전략의 특징 — save() 즉시 INSERT 실행
DbankWorksheet ws = DbankWorksheet.builder()
    .worksheetName("수학").build();

worksheetRepository.save(ws);
// → 즉시 INSERT 실행 (쓰기 지연 불가)
// → AUTO_INCREMENT로 생성된 ID를 Entity에 즉시 세팅
System.out.println(ws.getId());  // 1 (DB에서 할당받은 값)
```

> 💡 **왜 중요한가**: MySQL에서 `IDENTITY` 전략은 `save()` 호출 시 즉시 INSERT가 실행되어 쓰기 지연(batch insert)이 불가능하다는 제약이 있으므로, bulk insert 성능이 중요하면 SEQUENCE 전략이나 JDBC batch insert를 별도로 고려해야 한다.