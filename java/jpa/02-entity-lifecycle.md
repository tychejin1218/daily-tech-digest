### 1. JPA Entity 생명주기 — 4가지 상태와 save() 호출 기준 이해하기

JPA에서 Entity 객체는 비영속(new), 영속(managed), 준영속(detached), 삭제(removed) 4가지 상태를 가진다. `save()`는 비영속 상태의 Entity를 영속성 컨텍스트에 등록(INSERT)할 때만 필요하고, 이미 조회된 영속 상태 Entity는 필드 변경만으로 트랜잭션 커밋 시 자동 UPDATE된다.

```
  비영속 (new/transient)     영속 (managed)          준영속 (detached)        삭제 (removed)
┌──────────────────┐    ┌──────────────────┐    ┌──────────────────┐    ┌──────────────────┐
│ new Entity() 또는  │    │ 영속성 컨텍스트에    │    │ 트랜잭션 종료 후    │    │ DB에서 삭제 예정   │
│ builder().build() │───>│ 등록된 상태         │───>│ 더 이상 관리 안 됨  │    │ (물리 삭제)       │
│                   │    │ Dirty Checking 대상│    │ set해도 DB 반영 X  │    │                  │
└──────────────────┘    └──────────────────┘    └──────────────────┘    └──────────────────┘
   persist() / save()      find() / 쿼리 조회       트랜잭션 종료             remove()
```

```java
// 비영속 → 영속 (새 Entity 저장 → save 필요)
DbankWorksheet worksheet = request.toEntity(owner.getId(), owner);  // 비영속
worksheetRepository.save(worksheet);                                 // 영속 (INSERT)

// 조회 = 바로 영속 (save 불필요)
DbankWorksheet ws = queryRepository.selectWorksheetByIdAndUserId(1L, 5L);  // 영속
ws.softDelete(userId);  // 필드만 변경 → 트랜잭션 끝에 자동 UPDATE
```

> 💡 **왜 중요한가**: Entity 상태를 이해하면 불필요한 `save()` 호출을 제거하고, "조회한 Entity는 필드만 변경, 새로 만든 Entity만 save()"라는 명확한 규칙으로 코드를 작성할 수 있다.

---

### 2. 영속성 컨텍스트 — 1차 캐시, 동일성 보장, 스냅샷의 동작 원리

영속성 컨텍스트는 `@Transactional`이 시작되면 생성되고 종료되면 사라지는 Entity 관리 메모리 공간이다. 같은 ID로 재조회하면 DB를 치지 않고 1차 캐시에서 반환하며, 조회 시점의 상태를 스냅샷으로 보관해 Dirty Checking의 비교 기준으로 사용한다.

| 기능 | 설명 |
|------|------|
| **1차 캐시** | 같은 ID 재조회 시 DB 안 치고 메모리에서 반환 |
| **동일성 보장** | 같은 트랜잭션 내 같은 ID → 항상 같은 객체 (==) |
| **스냅샷 저장** | 조회 시점 상태를 복사해 보관 (Dirty Checking 기준) |
| **쓰기 지연** | SQL을 바로 보내지 않고 모아뒀다가 flush 시 일괄 전송 |

```java
@Transactional
public void example() {
    // 첫 번째 조회 → SELECT SQL 실행 → 1차 캐시에 저장
    DbankWorksheet ws1 = worksheetRepository.findById(1L);

    // 두 번째 조회 → DB 안 침 → 1차 캐시에서 반환
    DbankWorksheet ws2 = worksheetRepository.findById(1L);

    ws1 == ws2  // true (동일성 보장)
}
```

```
조회 시점 — 영속성 컨텍스트 내부:
┌─────────────────────────────┐     ┌─────────────────────────────┐
│     Entity (현재값)           │     │     스냅샷 (조회 시점 복사)    │
│ id=1                        │     │ id=1                        │
│ worksheetName="수학"         │     │ worksheetName="수학"         │
│ isDeleted=false             │     │ isDeleted=false             │
│ modifiedBy=null             │     │ modifiedBy=null             │
└─────────────────────────────┘     └─────────────────────────────┘
```

> 💡 **왜 중요한가**: 1차 캐시는 `findById` 같은 ID 기반 조회에서만 동작하고, QueryDSL/JPQL은 항상 SELECT를 실행한다는 점을 알아야 불필요한 최적화 시도를 피할 수 있다.