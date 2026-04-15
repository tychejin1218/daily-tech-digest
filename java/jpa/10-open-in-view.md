### 1. open-in-view: false — LAZY 로딩 버그를 조기에 발견하기

`spring.jpa.open-in-view`(OSIV)는 기본값이 `true`로, 영속성 컨텍스트를 Controller/View 계층까지 열어둔다. 이 경우 Service 밖에서도 LAZY 로딩이 동작해 편리하지만, DB 커넥션을 응답 완료까지 점유하여 커넥션 풀 고갈 위험이 있다. `false`로 설정하면 `@Transactional` 범위 밖에서 LAZY 접근 시 `LazyInitializationException`이 발생해 설계 문제를 조기에 발견할 수 있다.

```yaml
# application.yml
spring:
  jpa:
    open-in-view: false  # 운영 권장 설정
```

```
open-in-view: true (기본값)
┌──────────┐    ┌──────────┐    ┌──────────┐
│Controller│───>│ Service  │───>│Repository│
│  LAZY OK │    │@Transact.│    │          │
│  DB 커넥션 │    │  DB 커넥션 │    │  DB 커넥션 │
│  계속 점유 │    │  계속 점유 │    │          │
└──────────┘    └──────────┘    └──────────┘
                                 ↑ 커넥션 반환 시점: 응답 완료 후 (늦음!)

open-in-view: false (권장)
┌──────────┐    ┌──────────┐    ┌──────────┐
│Controller│───>│ Service  │───>│Repository│
│  LAZY 불가│    │@Transact.│    │          │
│  커넥션 없음│    │  DB 커넥션 │    │          │
│          │    │          │    │          │
└──────────┘    └──────────┘    └──────────┘
                 ↑ 커넥션 반환 시점: @Transactional 종료 (빠름!)
```

```java
// ❌ open-in-view: false일 때 — Controller에서 LAZY 접근 불가
@GetMapping("/worksheets/{id}")
public WorksheetResponse get(@PathVariable Long id) {
    DbankWorksheet ws = worksheetService.getWorksheet(id);
    ws.getQuestions().size();  // LazyInitializationException!
    // → Service에서 필요한 데이터를 DTO로 변환해서 반환해야 함
}

// ✅ Service에서 DTO로 변환 후 반환
@Transactional(readOnly = true)
public WorksheetDetailDto.Response getWorksheet(Long id) {
    DbankWorksheet ws = queryRepository.selectWorksheetById(id);
    // 여기서 필요한 연관 데이터를 모두 접근 → DTO로 변환
    return WorksheetDetailDto.Response.of(ws);
}
```

> 💡 **왜 중요한가**: OSIV `true`는 트래픽이 많아지면 커넥션 풀 고갈로 장애가 발생할 수 있으며, `false`로 설정하면 Service 계층에서 필요한 데이터를 명확히 준비하는 설계를 강제해 유지보수성과 안정성이 높아진다.

---

### 2. LAZY vs EAGER 로딩 — 연관관계 기본 전략과 설정 규칙

`FetchType.EAGER`는 Entity 조회 시 연관 Entity를 즉시 JOIN으로 함께 가져오고, `FetchType.LAZY`는 실제 접근 시점까지 로딩을 지연한다. **모든 연관관계는 LAZY로 설정하고**, 필요할 때만 Fetch Join이나 `@EntityGraph`로 함께 조회하는 것이 원칙이다.

```java
// ❌ EAGER — 문제지 조회할 때마다 문항도 무조건 함께 조회
@OneToMany(mappedBy = "worksheet", fetch = FetchType.EAGER)
private List<DbankWorksheetQuestion> questions;
// → 문제지 목록만 필요한 API에서도 불필요한 JOIN 발생

// ✅ LAZY — 문항이 필요한 시점에만 조회
@OneToMany(mappedBy = "worksheet", fetch = FetchType.LAZY)
private List<DbankWorksheetQuestion> questions;
// → 문항이 필요하면 Fetch Join으로 명시적 조회
```

**기본 FetchType 정리:**

| 연관관계 | 기본값 | 권장값 |
|---------|--------|--------|
| `@ManyToOne` | EAGER | **LAZY로 변경 필수** |
| `@OneToOne` | EAGER | **LAZY로 변경 필수** |
| `@OneToMany` | LAZY | 유지 |
| `@ManyToMany` | LAZY | 유지 |

```java
// @ManyToOne은 기본이 EAGER이므로 반드시 LAZY로 변경
@ManyToOne(fetch = FetchType.LAZY)
@JoinColumn(name = "worksheet_id")
private DbankWorksheet worksheet;
```

> 💡 **왜 중요한가**: `@ManyToOne`과 `@OneToOne`의 기본값이 EAGER이므로, LAZY로 변경하지 않으면 연관 Entity를 전혀 사용하지 않는 조회에서도 불필요한 JOIN이 발생해 성능이 저하된다.