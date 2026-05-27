### Q1. cascade를 걸면 연관관계의 주인이 바뀌나요? 둘은 같은 개념인가요?

다른 개념이다. **연관관계의 주인**은 "누가 FK 값을 쓰느냐"(@ManyToOne 쪽)의 문제이고, **cascade**는 "부모에 한 영속성 작업(persist/remove 등)을 자식에게도 전파하느냐"의 문제다. cascade를 PERSIST로 걸면 부모를 save할 때 자식도 함께 INSERT되지만, FK 값 자체는 여전히 주인 쪽 세팅으로 채워진다.

```java
@OneToMany(mappedBy = "worksheet", cascade = CascadeType.PERSIST)
private List<DbankWorksheetQuestion> questions = new ArrayList<>();
// 부모 save → 자식도 INSERT(cascade), 단 FK는 question.setWorksheet()로 채워야 함
```

> 💡 **정리**: 주인=FK 관리 주체, cascade=작업 전파. 둘은 별개다.

---

### Q2. `CascadeType.ALL`을 그냥 붙이면 안 되나요?

ALL에는 `REMOVE`가 포함된다. 부모를 삭제하면 연관된 자식이 전부 물리 DELETE되는데, 자식이 수백~수천 건이거나 다른 곳에서도 참조된다면 의도치 않은 대량 삭제 사고가 난다. PERSIST/MERGE만 필요하면 그 둘만 명시하는 게 안전하다.

```java
@OneToMany(mappedBy = "worksheet",
           cascade = {CascadeType.PERSIST, CascadeType.MERGE})  // REMOVE 제외
private List<DbankWorksheetQuestion> questions = new ArrayList<>();
```

> 💡 **정리**: ALL은 REMOVE까지 전파한다. 필요한 타입만 골라 명시하라.

---

### Q3. orphanRemoval과 CascadeType.REMOVE는 뭐가 다른가요?

둘 다 "부모 삭제 시 자식 삭제"는 같지만, **컬렉션에서 자식을 빼냈을 때**가 다르다. `CascadeType.REMOVE`는 부모가 살아있으면 자식이 컬렉션에서 빠져도 삭제하지 않는다. `orphanRemoval = true`는 부모와의 관계가 끊긴 고아 자식을 자동으로 DELETE한다.

```java
ws.getQuestions().remove(q);
// CascadeType.REMOVE만:  자식 삭제 안 됨 (부모 살아있음)
// orphanRemoval = true:  자식 DELETE 실행 ← 이게 차이
```

> 💡 **정리**: orphanRemoval은 "관계 끊긴 자식"까지 지운다. REMOVE는 부모 삭제 시에만.

---

### Q4. 컬렉션을 `setQuestions(newList)`로 통째 교체하면 왜 위험한가요?

orphanRemoval이 켜진 상태에서 컬렉션 참조를 새 리스트로 바꾸면, Hibernate가 **기존 컬렉션의 모든 항목을 고아로 인식**해 전부 DELETE한 뒤 새로 INSERT한다. 기존 객체를 유지하려면 참조를 갈아끼우지 말고 기존 컬렉션을 `clear()` 후 `addAll()`로 내용만 바꿔야 한다.

```java
// ❌ ws.setQuestions(newList);          // 기존 전부 DELETE 후 재INSERT
ws.getQuestions().clear();               // ✅ 기존 컬렉션 유지하며 내용 교체
ws.getQuestions().addAll(newList);
```

> 💡 **정리**: orphanRemoval에선 컬렉션 참조 교체 금지. clear()+addAll()로 내용만 바꾼다.

---

### Q5. 우리 프로젝트는 왜 cascade REMOVE/orphanRemoval을 안 쓰나요?

이 프로젝트는 물리 삭제 대신 **소프트 삭제(softDelete)** 패턴을 쓰기 때문이다. 자식을 진짜 DELETE하는 게 아니라 `is_deleted` 플래그만 바꾸므로, 자동 물리 삭제를 일으키는 CASCADE REMOVE/orphanRemoval은 오히려 위험하다. 부모와 자식을 각각 명시적으로 softDelete하는 편이 이력 보존과 의도 표현에 맞다.

```java
worksheets.forEach(w -> w.softDelete(userId));
questions.forEach(q -> q.softDelete(userId));  // 명시적 소프트 삭제
```

> 💡 **정리**: 소프트 삭제 프로젝트에선 자동 물리 삭제(cascade REMOVE/orphanRemoval)를 피하고 명시적으로 처리한다.
