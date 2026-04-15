### 1. @Version 낙관적 락 — 동시 수정 충돌 방지

낙관적 락(Optimistic Locking)은 `@Version` 필드를 사용해 동시에 같은 Entity를 수정할 때 충돌을 감지하는 메커니즘이다. UPDATE 시 WHERE 절에 version 값을 포함해, 다른 트랜잭션이 먼저 수정했으면 `OptimisticLockException`을 발생시킨다. DB 락을 잡지 않아 성능 저하가 없으며, 충돌이 드문 환경에 적합하다.

```java
@Entity
public class DbankWorksheet extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Version  // 수정할 때마다 자동으로 +1 증가
    private Long version;

    private String worksheetName;
}
```

```
동시 수정 시나리오:

  트랜잭션 A (version=1 읽음)       트랜잭션 B (version=1 읽음)
  ─────────────────────          ─────────────────────
  ws.setName("수학A");             ws.setName("수학B");
       │                               │
       ▼                               ▼
  UPDATE SET name='수학A',          UPDATE SET name='수학B',
    version=2                        version=2
  WHERE id=1 AND version=1         WHERE id=1 AND version=1
       │                               │
       ▼                               ▼
  ✅ 성공 (1행 수정, version→2)     ❌ 실패 (0행 수정 → OptimisticLockException)
                                   → version이 이미 2로 바뀌어 WHERE 조건 불일치
```

```java
// 충돌 처리 — 재시도 또는 사용자 알림
@Transactional
public void updateWorksheet(Long id, String newName) {
    try {
        DbankWorksheet ws = worksheetRepository.findById(id).orElseThrow();
        ws.setWorksheetName(newName);
        // 커밋 시 version 충돌이면 예외 발생
    } catch (OptimisticLockException e) {
        // 방법 1: 재시도
        // 방법 2: "다른 사용자가 수정했습니다" 알림
        throw new ConflictException("다른 사용자가 이미 수정했습니다. 새로고침 후 다시 시도해주세요.");
    }
}
```

> 💡 **왜 중요한가**: `@Version` 없이 동시 수정을 허용하면 나중에 커밋한 트랜잭션이 먼저 커밋한 내용을 덮어쓰는 Lost Update 문제가 발생하며, `@Version` 한 줄로 이를 자동 감지할 수 있다.

---

### 2. @Modifying 벌크 연산 — 대량 데이터를 한 번의 SQL로 처리하기

JPA의 Dirty Checking은 Entity를 하나씩 조회해서 변경하므로, 대량 데이터 처리 시 SELECT N번 + UPDATE N번이 발생한다. `@Modifying` + `@Query`로 벌크 연산을 실행하면 단 한 번의 SQL로 수천 건을 처리할 수 있어 성능이 극적으로 향상된다.

```java
// ❌ Dirty Checking 방식 — 1000건이면 SELECT 1번 + UPDATE 1000번
@Transactional
public void bulkSoftDelete(List<Long> ids, Long userId) {
    List<DbankWorksheet> worksheets = worksheetRepository.findAllById(ids);
    worksheets.forEach(w -> w.softDelete(userId));  // 1000번 UPDATE
}

// ✅ 벌크 연산 — 1000건이든 10000건이든 UPDATE 1번
public interface WorksheetRepository extends JpaRepository<DbankWorksheet, Long> {

    @Modifying(clearAutomatically = true)  // 벌크 연산 후 영속성 컨텍스트 초기화
    @Query("UPDATE DbankWorksheet w SET w.isDeleted = true, " +
           "w.deletedBy = :userId, w.deletedAt = CURRENT_TIMESTAMP, " +
           "w.modifiedBy = :userId " +
           "WHERE w.id IN :ids AND w.isDeleted = false")
    int bulkSoftDelete(@Param("ids") List<Long> ids, @Param("userId") Long userId);
    // 반환값: 수정된 행 수
}
```

```
Dirty Checking vs 벌크 연산 비교 (1000건 기준):

Dirty Checking:
  SELECT * FROM dbank_worksheet WHERE id IN (...);  -- 1번
  UPDATE dbank_worksheet SET ... WHERE id = 1;       -- 1번
  UPDATE dbank_worksheet SET ... WHERE id = 2;       -- 2번
  ...
  UPDATE dbank_worksheet SET ... WHERE id = 1000;    -- 1000번
  → 총 1001번 SQL

벌크 연산 (@Modifying):
  UPDATE dbank_worksheet SET ... WHERE id IN (...) AND is_deleted = false;
  → 총 1번 SQL
```

```java
// ⚠️ 벌크 연산 주의사항 — 영속성 컨텍스트를 무시하고 DB에 직접 실행
@Transactional
public void example() {
    DbankWorksheet ws = worksheetRepository.findById(1L).orElseThrow();
    // ws는 영속성 컨텍스트에 isDeleted=false로 캐싱됨

    worksheetRepository.bulkSoftDelete(List.of(1L), 5L);
    // DB는 isDeleted=true로 변경됨
    // 하지만 영속성 컨텍스트의 ws는 여전히 isDeleted=false!

    // clearAutomatically=true 이면 자동으로 영속성 컨텍스트 초기화
    // → 이후 조회 시 DB에서 새로 읽어옴
}
```

> 💡 **왜 중요한가**: 수백~수천 건 이상의 일괄 처리에서 Dirty Checking은 성능이 급격히 저하되므로, 벌크 연산을 활용해야 한다. 단, `clearAutomatically = true` 설정을 빠뜨리면 영속성 컨텍스트와 DB 상태가 불일치하는 버그가 발생할 수 있다.