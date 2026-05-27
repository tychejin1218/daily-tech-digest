### Q1. 컬렉션에 add()만 했는데 FK가 NULL로 저장됐어요. 왜죠?

`@OneToMany(mappedBy = ...)` 쪽은 **읽기 전용**이라 FK를 쓰지 못한다. FK는 연관관계의 주인인 `@ManyToOne`(FK 보유) 쪽이 관리하므로, 주인 쪽 필드를 세팅해야 DB에 반영된다. `worksheet.getQuestions().add(q)`만으로는 부족하고 `q.setWorksheet(worksheet)`가 있어야 한다.

```java
worksheet.getQuestions().add(q);   // ⚠️ 이것만으론 FK 반영 안 됨
q.setWorksheet(worksheet);         // ✅ 주인 쪽 세팅 → FK 저장
```

> 💡 **정리**: mappedBy 쪽은 읽기 전용. FK는 주인(@ManyToOne) 쪽 세팅으로만 저장된다.

---

### Q2. 연관관계의 주인은 어떻게 정하나요?

**DB에서 FK를 가진 테이블 쪽**이 주인이고, Entity에서는 `@ManyToOne` + `@JoinColumn`이 붙는 쪽이다. 주인이 FK 값을 쓰고, 반대쪽(`@OneToMany mappedBy`)은 조회만 한다. "FK가 어느 테이블에 있나"를 먼저 보면 헷갈리지 않는다.

```java
class DbankWorksheetQuestion {        // FK(worksheet_id) 보유 → 주인
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "worksheet_id")
    private DbankWorksheet worksheet;
}
class DbankWorksheet {
    @OneToMany(mappedBy = "worksheet")  // 주인 아님(읽기 전용)
    private List<DbankWorksheetQuestion> questions = new ArrayList<>();
}
```

> 💡 **정리**: FK 가진 쪽(@ManyToOne)이 주인. mappedBy엔 주인의 필드명을 적는다.

---

### Q3. `@ManyToOne`은 기본이 EAGER인데, 왜 굳이 LAZY로 바꾸나요?

EAGER면 해당 Entity를 조회할 때마다 연관 Entity까지 항상 조인/추가 쿼리로 가져온다. 목록 조회에서 이게 N+1로 번지기 쉽고, 필요 없는 데이터까지 매번 끌어온다. 그래서 **모든 연관관계는 LAZY로 두고, 필요할 때만 fetch join으로 가져오는 것**이 원칙이다. `@ManyToOne`, `@OneToOne`은 기본이 EAGER이므로 반드시 LAZY를 명시해야 한다.

```java
@ManyToOne(fetch = FetchType.LAZY)   // 기본 EAGER → 반드시 LAZY로
@JoinColumn(name = "worksheet_id")
private DbankWorksheet worksheet;
```

> 💡 **정리**: 연관관계는 전부 LAZY 기본, 필요 시 fetch join. @ManyToOne/@OneToOne은 LAZY 명시 필수.

---

### Q4. 양방향 매핑에서 toString이나 JSON 직렬화가 무한 루프에 빠지는데 어떻게 막나요?

양쪽이 서로를 참조하니 `worksheet → questions → worksheet → …`로 무한 반복된다. ①Lombok `@ToString(exclude = "questions")`로 한쪽을 끊고, ②API 응답으로는 Entity를 직접 반환하지 말고 **DTO로 변환**해 내보낸다. DTO 변환은 무한 루프뿐 아니라 불필요한 LAZY 로딩·내부 구조 노출도 함께 막아준다.

```java
@ToString(exclude = "questions")     // 한쪽 참조 끊기
// 컨트롤러는 Entity 대신 DTO 반환
public WorksheetDetailDto.Response get(Long id) { ... }
```

> 💡 **정리**: 한쪽 참조를 끊고, 컨트롤러 밖으로는 항상 DTO로 내보낸다.

---

### Q5. 편의 메서드 없이 단방향(@ManyToOne)만 쓰면 안 되나요?

된다. 오히려 **꼭 필요할 때만 양방향**을 쓰는 게 권장된다. 역방향 컬렉션(`@OneToMany`)이 실제로 필요 없다면 단방향 `@ManyToOne`만 두는 게 더 단순하고 버그가 적다. 양방향이 필요할 때만, 두 쪽을 한 번에 맞춰주는 편의 메서드로 객체 그래프와 DB 상태의 불일치를 막는다.

```java
public void setWorksheet(DbankWorksheet w) {
    if (this.worksheet != null) this.worksheet.getQuestions().remove(this);
    this.worksheet = w;
    if (w != null) w.getQuestions().add(this);
}
```

> 💡 **정리**: 단방향으로 충분하면 단방향. 양방향이 필요할 때만 편의 메서드로 양쪽을 맞춘다.
