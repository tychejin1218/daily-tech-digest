### Q1. BaseEntity는 왜 `@Entity`가 아니라 `@MappedSuperclass`인가요?

`@MappedSuperclass`는 그 자체로 테이블이 되지 않고, **상속한 Entity의 컬럼으로 매핑 정보만 내려주는** 부모 클래스다. 감사 필드(createdBy, createdAt 등)는 공통 컬럼으로 각 테이블에 포함시키고 싶을 뿐 별도 테이블이 필요 없으므로 `@MappedSuperclass`가 맞다. `@Entity`로 하면 상속 전략(테이블/조인)이 끼어들어 의도와 달라진다.

```java
@MappedSuperclass
@EntityListeners(AuditingEntityListener.class)
public abstract class BaseEntity { /* 공통 감사 필드 */ }
```

> 💡 **정리**: 공통 컬럼만 물려주고 테이블은 안 만들 때 @MappedSuperclass를 쓴다.

---

### Q2. `@CreatedBy`/`@LastModifiedBy` 값은 누가 자동으로 채우나요?

Spring Data JPA Auditing이 채운다. ①설정에 `@EnableJpaAuditing`을 켜고, ②`AuditorAware<Long>`을 구현해 "현재 사용자 ID"를 알려주면, 저장/수정 시 `AuditingEntityListener`가 그 값을 `@CreatedBy`/`@LastModifiedBy`에 자동 주입한다. 그래서 `setCreatedBy()`를 수동 호출할 필요가 없다.

```java
@Component
public class AuditorAwareImpl implements AuditorAware<Long> {
    public Optional<Long> getCurrentAuditor() { /* SecurityContext에서 userId 추출 */ }
}
```

> 💡 **정리**: @EnableJpaAuditing + AuditorAware가 생성자/수정자 ID를 자동으로 채운다.

---

### Q3. Entity에 Lombok `@EqualsAndHashCode`를 그냥 붙이면 왜 안 되나요?

기본값이 **모든 필드를 비교**하기 때문이다. Entity는 필드가 자주 바뀌는데, 필드가 바뀌면 hashCode도 바뀌어 `Set`/`Map`에 넣어둔 Entity를 다시 못 찾는 일이 생긴다. 또 LAZY 프록시 필드까지 건드리면 의도치 않은 초기화 쿼리가 나간다. 그래서 ID 기반으로 직접 구현해야 한다.

> 💡 **정리**: 전체 필드 비교는 필드 변경 시 hashCode가 깨진다. Entity는 ID 기반으로 직접 구현.

---

### Q4. hashCode를 왜 `getClass().hashCode()` 같은 고정값으로 두나요?

IDENTITY 전략에선 persist 전엔 id가 null이고 저장 후 값이 채워진다. id로 hashCode를 만들면 **저장 전후로 hashCode가 바뀌어** Set에 넣어둔 객체를 잃어버린다. 클래스 기반 고정값을 쓰면 id가 null→할당으로 바뀌어도 hashCode가 불변이라 안전하다. Entity 수가 많지 않으면 해시 분포 손해는 무시할 만하다.

```java
@Override public int hashCode() { return getClass().hashCode(); }  // 불변
```

> 💡 **정리**: id는 저장 시점에 바뀌므로, 불변인 클래스 기반 고정 hashCode가 안전하다.

---

### Q5. equals에서 id가 null이면 왜 무조건 false를 반환하나요?

아직 저장 안 된 비영속 Entity는 id가 모두 null이다. 만약 id==null끼리 "같다"고 판정하면, 서로 다른 새 Entity 두 개가 Set에서 하나로 합쳐지는 사고가 난다. 그래서 `id != null && id.equals(...)`로, **식별자가 없는 동안은 절대 같지 않다**고 처리한다.

```java
return id != null && id.equals(that.getId());  // 비영속(id=null)끼리는 항상 다름
```

> 💡 **정리**: id가 없는 비영속 객체끼리 같다고 보면 위험 — null이면 false로 막는다.
