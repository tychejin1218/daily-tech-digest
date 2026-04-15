### 1. @Transactional 올바른 사용법 — readOnly 설정과 Dirty Checking 동작 조건

`@Transactional`은 Dirty Checking이 동작하기 위한 필수 조건이다. 이 어노테이션이 없으면 영속성 컨텍스트가 관리되지 않아 필드를 변경해도 DB에 반영되지 않는다. 조회 전용 메서드에는 `readOnly = true`를 설정하면 Read DB로 라우팅되어 성능 이점을 얻을 수 있고, 실수로 변경을 시도하면 예외가 발생해 안전하다.

```java
// 조회 전용 → Read DB 라우팅 (성능 이점)
@Transactional(readOnly = true)
public WorksheetDetailDto.Response getWorksheet(Long id) { ... }

// 변경 작업 → Write DB 라우팅
@Transactional
public void deleteWorksheets(WorksheetDeleteDto.Request request) { ... }
```

```java
// ❌ @Transactional 없으면 Dirty Checking 안 됨
public void noTransaction() {
    DbankWorksheet ws = repository.findById(1L).orElseThrow();
    ws.softDelete(5L);  // DB에 반영 안 됨!
}

// ❌ readOnly=true 에서 변경 시도 → 예외 발생
@Transactional(readOnly = true)
public void readOnlyUpdate() {
    DbankWorksheet ws = repository.findById(1L).orElseThrow();
    ws.softDelete(5L);  // 예외!
}
```

> 💡 **왜 중요한가**: `@Transactional` 누락은 Dirty Checking이 동작하지 않아 변경이 DB에 반영되지 않는 흔한 버그의 원인이며, `readOnly` 설정은 Read/Write DB 분리 환경에서 성능 최적화의 기본이다.

---

### 2. 디뱅크 프로젝트의 Entity 변경 패턴과 BaseEntity 공통 메서드 정리

프로젝트에서 Entity 변경은 생성(save), 수정(Dirty Checking), 소프트 삭제(Dirty Checking) 3가지 패턴으로 이루어진다. `BaseEntity`에 정의된 `softDelete()`와 `markModifiedBy()` 공통 메서드를 통해 일관된 방식으로 변경 이력을 관리하며, `modified_ts`는 Entity가 아닌 DB의 `ON UPDATE CURRENT_TIMESTAMP`가 자동 갱신한다.

| 작업 | 패턴 | save() 필요 |
|------|------|-------------|
| 생성 | `builder().build()` → `repository.save()` | O |
| 수정 | 조회 → setter/메서드 호출 | X (Dirty Checking) |
| 소프트 삭제 | 조회 → `softDelete(userId)` | X (Dirty Checking) |

```java
// 소프트 삭제 — 모든 Entity 공통 (BaseEntity)
entity.softDelete(userId);
// → modifiedBy, isDeleted, deletedBy, deletedAt 일괄 설정
// → modified_ts는 DB ON UPDATE CURRENT_TIMESTAMP 자동 갱신

// 수정자 기록 — 모든 Entity 공통 (BaseEntity)
entity.markModifiedBy(userId);
// → modifiedBy만 설정
```

```
modified_ts 자동 갱신 원리:

코드: entity.softDelete(userId)     ← modifiedBy, isDeleted 등 변경
  ↓
JPA: UPDATE SET modified_by=5, is_deleted=true, ...  WHERE id=1
  ↓
MySQL: ON UPDATE CURRENT_TIMESTAMP  ← modified_ts 자동 갱신
```

`modified_ts`는 Entity에서 `updatable=false`로 설정되어 JPA가 건드리지 않고, DB의 `ON UPDATE CURRENT_TIMESTAMP`가 row 변경 시 자동으로 현재 시각을 넣는다.

> 💡 **왜 중요한가**: 프로젝트 전체에서 일관된 Entity 변경 패턴을 이해하면, 새로운 기능 구현 시 생성/수정/삭제 각각에 맞는 올바른 패턴을 즉시 적용할 수 있다.