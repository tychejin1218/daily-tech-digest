### 1. CaseBuilder — 조건부 컬럼 표현식과 동적 정렬

QueryDSL의 `CaseBuilder`는 SQL의 `CASE WHEN`을 자바 코드로 작성하게 해준다. 단순 라벨 매핑부터, 정렬 우선순위를 케이스로 부여하는 **"우선순위 정렬"** 패턴까지 활용도가 높다. SELECT/ORDER BY/WHERE 어디서든 표현식으로 끼워 넣을 수 있다.

```java
QDbankWorksheet w = QDbankWorksheet.dbankWorksheet;

// 1. 컬럼값 → 라벨 매핑
StringExpression statusLabel = new CaseBuilder()
    .when(w.isDeleted.eq(true)).then("삭제됨")
    .when(w.createdAt.after(LocalDateTime.now().minusDays(7))).then("신규")
    .otherwise("일반");

List<Tuple> result = queryFactory
    .select(w.id, w.worksheetName, statusLabel)
    .from(w)
    .fetch();

// 2. 우선순위 정렬 — 특정 사용자 worksheet을 최상단에 노출
NumberExpression<Integer> priority = new CaseBuilder()
    .when(w.createdBy.eq("admin")).then(1)
    .when(w.createdBy.eq("vip")).then(2)
    .otherwise(3);

queryFactory
    .selectFrom(w)
    .orderBy(priority.asc(), w.createdAt.desc())
    .fetch();

// 3. 집계 시 조건부 카운트
queryFactory
    .select(
        w.createdBy,
        new CaseBuilder()
            .when(w.isDeleted.eq(false)).then(1)
            .otherwise(0).sum().as("activeCount")
    )
    .from(w)
    .groupBy(w.createdBy)
    .fetch();
```

```
CaseBuilder가 만드는 SQL:

new CaseBuilder()
    .when(is_deleted=true).then('삭제됨')
    .when(created_at>'...').then('신규')
    .otherwise('일반')
              ↓
CASE
    WHEN is_deleted = true       THEN '삭제됨'
    WHEN created_at > '...'      THEN '신규'
    ELSE '일반'
END
```

> 💡 **왜 중요한가**: "특정 항목을 무조건 최상단에 노출"하는 정렬 요구는 별도 컬럼 추가 없이 `CaseBuilder`로 가상 우선순위를 만들면 깔끔하게 해결되며, DB에 정렬 전용 컬럼을 두지 않아도 되어 스키마가 단순해진다.

---

### 2. Bulk 연산 — update / delete와 영속성 컨텍스트 불일치 함정

QueryDSL의 `update()`/`delete()`는 영속성 컨텍스트를 **거치지 않고** DB에 직접 쿼리를 날린다. 변경 감지(Dirty Checking)로 1건씩 UPDATE를 날리는 것보다 훨씬 빠르지만, 영속성 컨텍스트와 DB 상태가 어긋나기 때문에 **벌크 연산 직후 `em.flush()` + `em.clear()`** 로 컨텍스트를 비워야 한다.

```java
@Repository
@RequiredArgsConstructor
public class WorksheetBulkRepository {

    private final JPAQueryFactory queryFactory;
    private final EntityManager em;

    // ✅ Bulk Update — 한 번의 UPDATE로 여러 행 변경
    @Transactional
    public long softDeleteOld(LocalDateTime cutoff) {
        QDbankWorksheet w = QDbankWorksheet.dbankWorksheet;

        long affected = queryFactory
            .update(w)
            .set(w.isDeleted, true)
            .set(w.deletedAt, LocalDateTime.now())
            .where(w.createdAt.lt(cutoff).and(w.isDeleted.eq(false)))
            .execute();

        em.flush();   // 영속성 컨텍스트의 변경을 DB로 (보통 비어있지만 관행)
        em.clear();   // ★ 필수: 컨텍스트 비우기 — 이후 조회 시 DB 최신값 반영

        return affected;
    }

    // ✅ Bulk Delete — 물리 삭제
    @Transactional
    public long deletePurged() {
        QDbankWorksheet w = QDbankWorksheet.dbankWorksheet;

        long deleted = queryFactory
            .delete(w)
            .where(w.isDeleted.eq(true)
                .and(w.deletedAt.lt(LocalDateTime.now().minusMonths(6))))
            .execute();

        em.clear();
        return deleted;
    }
}
```

```
em.clear() 누락 시 발생하는 버그:

1. queryFactory.update(w).set(w.isDeleted, true)... .execute();
       ↓ DB: is_deleted = true 로 변경됨
       ↓ 영속성 컨텍스트: 아직 false 그대로 (캐시 stale)

2. DbankWorksheet ws = repo.findById(1L).get();
       ↓ 1차 캐시 HIT → is_deleted = false 반환 (DB와 불일치!)

3. ws.someBusinessMethod();   ← 잘못된 상태로 로직 실행

해결: bulk 직후 em.clear() → 다음 조회는 DB에서 fresh fetch
```

> 💡 **왜 중요한가**: 변경 감지로 1만 건을 업데이트하면 1만 번의 UPDATE 쿼리가 나가 트랜잭션이 길어지고 락 경합이 심해지지만, 벌크 연산은 단일 쿼리로 끝나는 대신 영속성 컨텍스트 동기화 책임이 개발자에게 넘어오므로 `em.clear()`를 빠뜨리면 잠재적 데이터 불일치 버그를 만든다.
