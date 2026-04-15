### 1. CascadeType — 부모 Entity 작업을 자식에게 전파하기

`cascade`는 부모 Entity에 대한 영속성 작업(persist, merge, remove 등)을 연관된 자식 Entity에도 자동으로 전파하는 설정이다. `CascadeType.ALL`은 모든 작업을 전파하므로 편리하지만, 자식이 다른 부모와도 연관되는 경우 의도치 않은 삭제가 발생할 수 있어 주의가 필요하다.

```java
@Entity
public class DbankWorksheet extends BaseEntity {

    // PERSIST + MERGE — 저장/수정만 전파 (안전한 선택)
    @OneToMany(mappedBy = "worksheet", cascade = {CascadeType.PERSIST, CascadeType.MERGE})
    private List<DbankWorksheetQuestion> questions = new ArrayList<>();
}
```

```java
// CascadeType.PERSIST — 부모 저장 시 자식도 함께 INSERT
DbankWorksheet worksheet = DbankWorksheet.builder()
    .worksheetName("수학").build();

DbankWorksheetQuestion q1 = new DbankWorksheetQuestion();
DbankWorksheetQuestion q2 = new DbankWorksheetQuestion();
worksheet.getQuestions().add(q1);
worksheet.getQuestions().add(q2);

worksheetRepository.save(worksheet);
// → INSERT INTO dbank_worksheet ...          (부모)
// → INSERT INTO dbank_worksheet_question ... (자식 q1) ← CASCADE 전파
// → INSERT INTO dbank_worksheet_question ... (자식 q2) ← CASCADE 전파
// 자식을 별도로 save() 하지 않아도 됨
```

**CascadeType 종류:**

| 타입 | 전파 동작 | 사용 시점 |
|------|---------|---------|
| `PERSIST` | 부모 저장 시 자식도 저장 | 부모와 자식을 함께 생성할 때 |
| `MERGE` | 부모 병합 시 자식도 병합 | 준영속 Entity를 다시 영속화할 때 |
| `REMOVE` | 부모 삭제 시 자식도 삭제 | 부모-자식 생명주기가 완전히 같을 때만 |
| `ALL` | 위 전부 포함 | 자식이 이 부모에만 종속될 때만 |

```java
// ❌ CascadeType.REMOVE 주의 — 의도치 않은 대량 삭제 위험
@OneToMany(mappedBy = "worksheet", cascade = CascadeType.ALL)
private List<DbankWorksheetQuestion> questions;

worksheetRepository.delete(worksheet);
// → 연결된 question 수백 건이 한 번에 DELETE (의도한 것인지 확인 필요)

// ✅ 프로젝트에서는 소프트 삭제 사용 — CASCADE REMOVE 불필요
worksheets.forEach(w -> w.softDelete(userId));
questions.forEach(q -> q.softDelete(userId));  // 명시적으로 소프트 삭제
```

> 💡 **왜 중요한가**: `CascadeType.ALL`을 무분별하게 사용하면 부모 삭제 시 연관된 자식이 모두 물리 삭제되는 사고가 발생할 수 있으며, 소프트 삭제 패턴에서는 CASCADE REMOVE 대신 명시적으로 각 Entity를 소프트 삭제하는 것이 안전하다.

---

### 2. orphanRemoval — 컬렉션에서 제거된 자식 Entity 자동 삭제

`orphanRemoval = true`는 부모의 컬렉션에서 자식 Entity를 제거하면 DB에서도 자동으로 DELETE하는 설정이다. `CascadeType.REMOVE`가 부모 삭제 시 자식을 삭제하는 것과 달리, orphanRemoval은 **부모는 살아있지만 관계가 끊어진 고아 객체**를 자동으로 정리한다.

```java
@Entity
public class DbankWorksheet extends BaseEntity {

    @OneToMany(mappedBy = "worksheet",
               cascade = CascadeType.ALL,
               orphanRemoval = true)  // 컬렉션에서 제거 시 DB DELETE
    private List<DbankWorksheetQuestion> questions = new ArrayList<>();
}
```

```java
// orphanRemoval = true 동작
@Transactional
public void removeQuestion(Long worksheetId, Long questionId) {
    DbankWorksheet ws = worksheetRepository.findById(worksheetId).orElseThrow();

    ws.getQuestions().removeIf(q -> q.getId().equals(questionId));
    // → 컬렉션에서 제거됨
    // → 트랜잭션 커밋 시 자동으로 DELETE FROM dbank_worksheet_question WHERE id = ?

    // 별도의 questionRepository.delete() 호출 불필요
}
```

```
CascadeType.REMOVE vs orphanRemoval 차이:

CascadeType.REMOVE:
  부모 삭제 → 자식도 삭제
  부모.getQuestions().remove(자식) → 자식 삭제 안 됨 (FK만 null)

orphanRemoval = true:
  부모 삭제 → 자식도 삭제 (REMOVE와 동일)
  부모.getQuestions().remove(자식) → 자식도 DB에서 삭제 ← 이게 차이!
```

```java
// ⚠️ orphanRemoval 주의사항
// 컬렉션을 새 리스트로 교체하면 기존 항목 전부 DELETE
ws.setQuestions(newQuestionList);
// → 기존 questions 전체가 orphan으로 인식 → 전부 DELETE

// ✅ 안전한 방법 — 기존 컬렉션을 수정
ws.getQuestions().clear();
ws.getQuestions().addAll(newQuestionList);
```

> 💡 **왜 중요한가**: orphanRemoval은 부모-자식 간 생명주기가 완전히 같은 경우(문제지-문항 등)에만 사용해야 하며, 자식이 다른 부모로 재할당될 수 있는 관계에서 사용하면 의도치 않은 삭제가 발생한다.