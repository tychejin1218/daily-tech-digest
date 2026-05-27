### Q1. setter만 불렀는데 UPDATE가 나가는 원리가 정확히 뭔가요?

영속성 컨텍스트는 조회 시점의 Entity 상태를 **스냅샷**으로 복사해 둔다. 커밋(flush) 시점에 현재 Entity와 스냅샷을 필드 단위로 비교해, 달라진 게 있으면 UPDATE SQL을 자동 생성한다. 그래서 `save()` 없이 값만 바꿔도 변경이 DB에 반영된다.

```java
DbankWorksheet ws = repo.findById(1L).get(); // 조회 시 스냅샷 저장
ws.softDelete(userId);                        // 현재값만 변경
// 커밋 시: 스냅샷 vs 현재 비교 → 다른 필드만 UPDATE
```

> 💡 **정리**: 조회 시 찍어둔 스냅샷과 커밋 시점 값을 비교하는 게 Dirty Checking이다.

---

### Q2. UPDATE할 때 전체 컬럼이 나가나요, 바뀐 컬럼만 나가나요?

Hibernate 기본은 **변경 여부와 무관하게 모든 컬럼을 UPDATE 문에 포함**한다(미리 만들어둔 SQL 재사용과 캐시 효율 때문). 정말 변경된 컬럼만 넣고 싶으면 `@DynamicUpdate`를 붙이면 된다. 다만 컬럼이 아주 많거나 LOB가 있는 경우가 아니면 기본값이 더 빠른 경우가 많아 무분별한 적용은 권장하지 않는다.

```java
@Entity
@DynamicUpdate   // 변경된 컬럼만 UPDATE문에 포함
public class DbankWorksheet extends BaseEntity { ... }
```

> 💡 **정리**: 기본은 전체 컬럼 UPDATE. 꼭 필요할 때만 @DynamicUpdate.

---

### Q3. flush와 commit은 어떻게 다른가요?

`flush()`는 변경 내용을 SQL로 만들어 DB에 **전송**하는 단계이고, 이 시점엔 아직 롤백이 가능하다. `commit()`은 트랜잭션을 **확정**해 되돌릴 수 없게 한다. `@Transactional` 메서드가 끝나면 flush → commit이 자동으로 순서대로 일어난다.

> 💡 **정리**: flush=SQL 전송(롤백 가능), commit=확정(롤백 불가). 트랜잭션 끝에 둘 다 자동.

---

### Q4. 값을 바꾼 뒤 같은 테이블을 조회했더니 UPDATE가 먼저 실행됐어요. 정상인가요?

정상이다. JPQL/QueryDSL 쿼리 실행 직전에는 **자동 flush**가 일어난다. 변경 내용을 DB에 먼저 반영해야 조회 결과가 일관되기 때문이다. 그래서 `softDelete` 후 목록을 다시 조회하면 `is_deleted=true`가 반영된 결과를 받는다.

```java
ws.softDelete(5L);                 // 아직 SQL 없음
queryRepository.selectList(req);   // 쿼리 전 자동 flush → UPDATE 먼저, 그다음 SELECT
```

> 💡 **정리**: JPQL/QueryDSL 실행 전 자동 flush가 일어나 변경이 먼저 DB에 반영된다.

---

### Q5. 분명 값을 바꿨는데 DB가 안 변해요. 어떤 경우인가요?

Dirty Checking이 안 먹는 세 가지가 대표적이다. ①`@Transactional`이 없어 영속성 컨텍스트가 유지되지 않을 때, ②트랜잭션이 끝나 Entity가 준영속이 됐을 때, ③`@Transactional(readOnly = true)`라 flush가 생략돼 변경이 무시될 때다. "값은 바꿨는데 UPDATE가 안 나간다"면 이 셋을 먼저 의심한다.

> 💡 **정리**: 트랜잭션 없음 / 준영속 / readOnly — 이 셋이면 변경이 DB에 안 간다.
