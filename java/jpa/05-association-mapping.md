### 1. @ManyToOne / @OneToMany — 연관관계 매핑의 기본

DB의 FK(외래 키) 관계를 Entity에서 객체 참조로 표현하는 것이 연관관계 매핑이다. `@ManyToOne`은 FK를 가진 쪽(N)에 설정하고, `@OneToMany`는 반대쪽(1)에 `mappedBy`로 읽기 전용 참조를 설정한다. **연관관계의 주인은 항상 FK가 있는 쪽(`@ManyToOne`)**이며, 주인만 DB에 값을 쓸 수 있다.

```
DB 테이블:
  dbank_worksheet (1) ←─── dbank_worksheet_question (N)
                            └── worksheet_id (FK)

Entity 매핑:
  DbankWorksheet (1) ←───── DbankWorksheetQuestion (N)
  @OneToMany(mappedBy)        @ManyToOne + @JoinColumn
  (읽기 전용)                   (연관관계의 주인 = FK 관리)
```

```java
// N쪽 (FK 보유) — 연관관계의 주인
@Entity
public class DbankWorksheetQuestion extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)  // LAZY 필수! (기본값이 EAGER)
    @JoinColumn(name = "worksheet_id")   // FK 컬럼명 지정
    private DbankWorksheet worksheet;
}

// 1쪽 — 읽기 전용 (mappedBy = "주인 쪽 필드명")
@Entity
public class DbankWorksheet extends BaseEntity {

    @OneToMany(mappedBy = "worksheet")  // worksheet 필드가 FK를 관리
    private List<DbankWorksheetQuestion> questions = new ArrayList<>();
}
```

```java
// 연관관계 설정 — 주인 쪽에서만 FK가 반영됨
DbankWorksheetQuestion question = new DbankWorksheetQuestion();
question.setWorksheet(worksheet);  // ✅ 주인 쪽 세팅 → FK 반영됨

worksheet.getQuestions().add(question);  // ⚠️ 이것만으로는 FK 반영 안 됨
// → 양쪽 다 세팅하는 편의 메서드를 사용하는 것이 안전
```

> 💡 **왜 중요한가**: `mappedBy` 쪽에서만 연관관계를 설정하면 FK가 NULL로 저장되는 흔한 실수가 발생하며, 연관관계의 주인 개념을 이해해야 어느 쪽에서 값을 세팅해야 DB에 반영되는지 정확히 알 수 있다.

---

### 2. 양방향 연관관계 — 편의 메서드와 무한 루프 방지

양방향 연관관계에서는 주인 쪽과 역방향 쪽을 동시에 세팅하는 **편의 메서드**를 만들어야 객체 그래프와 DB 상태가 일치한다. 또한 `toString()`, JSON 직렬화에서 양쪽이 서로를 참조해 **무한 루프**가 발생할 수 있으므로 반드시 한쪽을 끊어야 한다.

```java
// ✅ 편의 메서드 — 양쪽을 동시에 세팅
@Entity
public class DbankWorksheetQuestion {

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "worksheet_id")
    private DbankWorksheet worksheet;

    // 편의 메서드
    public void setWorksheet(DbankWorksheet worksheet) {
        // 기존 관계 제거
        if (this.worksheet != null) {
            this.worksheet.getQuestions().remove(this);
        }
        this.worksheet = worksheet;
        if (worksheet != null) {
            worksheet.getQuestions().add(this);
        }
    }
}
```

```java
// ❌ 무한 루프 위험 — Lombok @ToString, @Data
@Entity
@ToString  // worksheet.toString() → questions.toString() → worksheet.toString() → ∞
public class DbankWorksheet {
    @OneToMany(mappedBy = "worksheet")
    private List<DbankWorksheetQuestion> questions;
}

// ✅ 연관관계 필드 제외
@Entity
@ToString(exclude = "questions")
public class DbankWorksheet { ... }

// ✅ 또는 Lombok 대신 직접 구현
@Override
public String toString() {
    return "DbankWorksheet{id=" + id + ", name=" + worksheetName + "}";
}
```

```java
// ❌ JSON 직렬화 무한 루프 — Controller에서 Entity 직접 반환
@GetMapping("/worksheets/{id}")
public DbankWorksheet get(@PathVariable Long id) {
    return worksheetRepository.findById(id).orElseThrow();
    // worksheet → questions → worksheet → questions → ∞
}

// ✅ DTO로 변환 후 반환 (Entity를 Controller 밖으로 노출하지 않음)
@GetMapping("/worksheets/{id}")
public WorksheetDetailDto.Response get(@PathVariable Long id) {
    return worksheetService.getWorksheet(id);
}
```

> 💡 **왜 중요한가**: Entity를 API 응답으로 직접 반환하면 양방향 참조에 의한 무한 루프, 불필요한 LAZY 로딩, 내부 구조 노출 문제가 동시에 발생하므로, 반드시 DTO로 변환하는 것이 원칙이다.