### 1. Dirty Checking — save() 없이 UPDATE가 실행되는 원리

Dirty Checking은 트랜잭션 커밋 시 스냅샷과 현재 Entity를 필드 단위로 비교하여, 변경된 필드만 UPDATE SQL을 자동 생성하는 메커니즘이다. 이것이 JPA의 핵심이며, 조회된 Entity에서 `save()`를 호출하지 않아도 setter만으로 DB가 갱신되는 이유다.

```
트랜잭션 커밋 시점:

  Entity 현재값                스냅샷 (조회 시점)
  ─────────────               ────────────────
  isDeleted=true       ←비교→  isDeleted=false       ← 다르다! → UPDATE 대상
  modifiedBy=5         ←비교→  modifiedBy=null       ← 다르다! → UPDATE 대상
  deletedBy=5          ←비교→  deletedBy=null        ← 다르다! → UPDATE 대상
  worksheetName="수학"  ←비교→  worksheetName="수학"   ← 같다   → UPDATE 제외

  ↓ 변경된 필드만 SQL 생성

  UPDATE dbank_worksheet
  SET is_deleted=true, modified_by=5, deleted_by=5, deleted_at='2026-04-15T...'
  WHERE id=1;
```

```java
// WorksheetStorageService.deleteWorksheets()

@Transactional  // ① 트랜잭션 시작 → 영속성 컨텍스트 생성
public void deleteWorksheets(WorksheetDeleteDto.Request request) {

    // ② 조회 → SELECT 실행 → 영속성 컨텍스트에 등록 + 스냅샷 저장
    List<DbankWorksheet> worksheets =
        worksheetQueryRepository.selectWorksheetListByIdsAndUserId(
            request.getIds(), request.getUserId());

    Long userId = request.getUserId();

    // ③ 필드 변경 (Java 객체만 바뀜, 이 시점에 SQL 실행 없음)
    worksheets.forEach(w -> w.softDelete(userId));

}   // ④ 메서드 종료 → @Transactional 끝
    //    → flush() 자동 호출
    //    → Dirty Checking (스냅샷 vs 현재 비교)
    //    → UPDATE SQL 생성 및 DB 전송
    //    → COMMIT
```

> 💡 **왜 중요한가**: Dirty Checking을 이해하면 "조회한 Entity는 필드만 변경, 새로 만든 Entity만 save()"라는 규칙의 근거를 정확히 알 수 있고, 불필요한 `save()` 호출을 자신 있게 제거할 수 있다.

---

### 2. Flush — 영속성 컨텍스트의 변경 내용이 DB에 전송되는 시점

Flush는 영속성 컨텍스트의 변경 내용을 SQL로 변환하여 DB에 전송하는 동작이다. `flush()`는 SQL을 보내지만 아직 롤백이 가능한 상태이고, `commit()`이 호출되어야 트랜잭션이 확정된다. `@Transactional` 종료 시 `flush()` → `commit()`이 자동으로 순서대로 실행된다.

```
flush()  → 변경 감지 → SQL 생성 → DB에 전송 (아직 롤백 가능)
commit() → DB 트랜잭션 확정 (되돌릴 수 없음)

@Transactional 종료 시:
    flush()  →  commit()
    (자동)       (자동)
```

| flush 자동 발생 시점 | 설명 |
|------|------|
| 트랜잭션 커밋 직전 | `@Transactional` 메서드 종료 시 |
| JPQL/QueryDSL 쿼리 실행 전 | 변경 후 같은 테이블을 조회하면, 변경이 반영된 결과를 보장하기 위해 |

```java
@Transactional
public void example() {
    DbankWorksheet ws = queryRepository.selectWorksheetByIdAndUserId(1L, 5L);
    ws.softDelete(5L);  // 필드 변경 (SQL 아직 없음)

    // QueryDSL 쿼리 실행 전 자동 flush → UPDATE 먼저 실행
    // → 아래 조회에서 isDeleted=true 상태가 반영됨
    List<DbankWorksheet> list = queryRepository.selectWorksheetList(request);
}
```

> 💡 **왜 중요한가**: 변경 후 같은 테이블을 조회할 때 자동 flush가 발생한다는 점을 알아야, 예상치 못한 UPDATE 실행 시점이나 쿼리 결과의 일관성 문제를 이해할 수 있다.