### 1. BaseEntity + AuditorAware — 감사 필드 중복 제거와 자동 주입

`BaseEntity`에 공통 감사 필드(createdBy, modifiedBy, createdAt, modifiedAt)를 정의하고 `@MappedSuperclass`로 상속하면 모든 Entity에서 중복 코드를 제거할 수 있다. `AuditorAware`를 구현하면 `@CreatedBy`, `@LastModifiedBy` 필드에 현재 사용자 ID가 자동 주입되어 수동 설정이 불필요해진다.

```java
@Getter
@MappedSuperclass
@EntityListeners(AuditingEntityListener.class)
public abstract class BaseEntity {

    @CreatedBy
    @Column(updatable = false)
    private Long createdBy;

    @LastModifiedBy
    private Long modifiedBy;

    @CreatedDate
    @Column(updatable = false)
    private LocalDateTime createdAt;

    @LastModifiedDate
    private LocalDateTime modifiedAt;

    private Boolean isDeleted = false;
    private Long deletedBy;
    private LocalDateTime deletedAt;

    public void softDelete(Long userId) {
        this.isDeleted = true;
        this.deletedBy = userId;
        this.deletedAt = LocalDateTime.now();
        this.modifiedBy = userId;
    }

    public void markModifiedBy(Long userId) {
        this.modifiedBy = userId;
    }
}
```

```java
// AuditorAware 구현 — SecurityContext에서 현재 사용자 ID 추출
@Component
public class AuditorAwareImpl implements AuditorAware<Long> {
    @Override
    public Optional<Long> getCurrentAuditor() {
        return Optional.ofNullable(SecurityContextHolder.getContext())
            .map(SecurityContext::getAuthentication)
            .filter(Authentication::isAuthenticated)
            .map(auth -> ((UserDetails) auth.getPrincipal()).getId());
    }
}

// @EnableJpaAuditing 활성화 필요
@Configuration
@EnableJpaAuditing
public class JpaConfig { }
```

```java
// 사용 — createdBy, modifiedBy 자동 주입
@Entity
public class DbankWorksheet extends BaseEntity {
    private String worksheetName;
    // createdBy, modifiedBy 등은 BaseEntity에서 상속
    // save() 시 @CreatedBy가 AuditorAware에서 자동 주입
}
```

> 💡 **왜 중요한가**: 감사 필드를 Entity마다 반복 정의하면 누락이나 불일치가 발생하기 쉬우며, `AuditorAware`를 통한 자동 주입으로 수동 `setCreatedBy()` 호출을 제거하면 실수를 원천 차단할 수 있다.

---

### 2. Entity equals/hashCode — 영속성 컨텍스트 정합성을 위한 올바른 구현

JPA Entity에서 `equals()`와 `hashCode()`를 잘못 구현하면 `Set`이나 `Map`에서 같은 Entity가 중복 저장되거나, 영속성 컨텍스트의 동일성 보장이 깨질 수 있다. Lombok의 `@EqualsAndHashCode`를 그대로 사용하면 모든 필드를 비교하므로, 반드시 비즈니스 키(ID)만 사용하도록 직접 구현해야 한다.

```java
// ❌ Lombok 기본 — 모든 필드 비교 (위험)
@EqualsAndHashCode  // id, name, isDeleted... 전부 비교
public class DbankWorksheet { }
// → 필드 변경 시 hashCode가 바뀌어 Set/Map에서 못 찾음

// ❌ 생성된 ID만 비교 — new 상태에서 id=null끼리 같다고 판정
@Override
public boolean equals(Object o) {
    if (this == o) return true;
    if (!(o instanceof DbankWorksheet)) return false;
    return id != null && id.equals(((DbankWorksheet) o).id);
    // id가 null(비영속)이면 false 반환 — 안전
}
```

```java
// ✅ 권장 패턴 — ID 기반 + null 방어
@Entity
public class DbankWorksheet extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (!(o instanceof DbankWorksheet that)) return false;
        // id가 null(아직 persist 전)이면 절대 같지 않음
        return id != null && id.equals(that.getId());
    }

    @Override
    public int hashCode() {
        // 고정값 반환 → id가 null→할당으로 바뀌어도 hashCode 불변
        // Set/Map 성능에 영향 미미 (Entity 수가 적으므로)
        return getClass().hashCode();
    }
}
```

```
equals/hashCode 전략 비교:

| 전략                  | new 상태 | 영속 상태 | Set 안정성 | 비고           |
|----------------------|---------|---------|-----------|---------------|
| Lombok 기본 (전체 필드) | ⚠️      | ❌       | ❌         | 필드 변경 시 깨짐 |
| ID만 비교              | ✅       | ✅       | ⚠️        | hashCode 주의  |
| ID + 고정 hashCode    | ✅       | ✅       | ✅         | 권장           |
```

> 💡 **왜 중요한가**: Entity의 `equals/hashCode`가 잘못되면 `Set`에 같은 Entity가 중복 저장되거나, 영속성 컨텍스트에서 Entity를 찾지 못하는 미묘한 버그가 발생하며, 특히 양방향 연관관계에서 컬렉션 관리가 정상 동작하지 않는다.