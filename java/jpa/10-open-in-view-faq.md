### Q1. open-in-view는 true/false 중 뭐가 맞나요?

운영에서는 보통 `false`를 권장한다. 기본값 `true`(OSIV on)는 영속성 컨텍스트와 DB 커넥션을 **응답이 끝날 때까지** 열어두므로, 트래픽이 몰리면 커넥션을 오래 점유해 풀이 고갈된다. `false`면 커넥션이 `@Transactional` 종료 시 바로 반환돼 안정적이지만, Service 밖에서 LAZY 접근이 막히므로 데이터를 미리 준비해야 한다.

```yaml
spring.jpa.open-in-view: false   # 운영 권장
```

> 💡 **정리**: 운영은 OSIV false 권장(커넥션 빨리 반환). 대신 Service에서 데이터를 미리 꺼낸다.

---

### Q2. `LazyInitializationException`은 정확히 언제, 왜 나나요?

LAZY 연관은 처음엔 실제 데이터 대신 **프록시(가짜 객체)**로 채워져 있고, 실제로 접근하는 순간 영속성 컨텍스트가 DB에서 값을 채워준다. 그런데 트랜잭션이 끝나 영속성 컨텍스트가 닫힌 뒤(준영속 상태) 프록시를 건드리면, 채워줄 컨텍스트가 없어 이 예외가 난다. OSIV false면 Controller에서 LAZY 접근 시 자주 마주친다.

```java
DbankWorksheet ws = service.getWorksheet(id);  // 트랜잭션 종료됨
ws.getQuestions().size();                       // 프록시 초기화 시도 → 예외!
```

> 💡 **정리**: 트랜잭션 닫힌 뒤 LAZY 프록시를 건드리면 LazyInitializationException. 트랜잭션 안에서 초기화하라.

---

### Q3. LAZY가 만든다는 "프록시"가 정확히 뭔가요?

Hibernate가 런타임에 만든 **원본 Entity를 상속한 가짜 자식 객체**다. 처음엔 PK만 들고 있고 나머지 필드는 비어 있다가, 실제 메서드(예: `getWorksheetName()`)가 호출되는 순간 DB에 SELECT를 날려 값을 채운다(지연 초기화). 그래서 PK만 쓰면 추가 쿼리 없이 동작하지만, 다른 필드를 건드리면 그때 쿼리가 나간다.

```java
DbankWorksheet w = question.getWorksheet();  // 프록시 (아직 SELECT 안 함)
w.getId();                                    // PK는 이미 알아서 쿼리 없음
w.getWorksheetName();                         // 이 순간 SELECT 실행(초기화)
```

> 💡 **정리**: 프록시는 PK만 든 상속 객체. 실제 필드 접근 시 SELECT로 채워진다.

---

### Q4. `getReference()`와 `findById()`는 뭐가 다른가요?

`findById()`는 즉시 SELECT를 날려 **실제 Entity**를 가져온다. `getReference()`는 DB를 치지 않고 **프록시만** 돌려준다. 연관관계를 걸 때처럼 PK만 있으면 되는 경우 `getReference()`로 불필요한 조회를 아낄 수 있다. 단 트랜잭션이 끝난 뒤 프록시 필드에 접근하면 역시 `LazyInitializationException`이 난다.

```java
DbankWorksheet ref = em.getReference(DbankWorksheet.class, 1L); // SELECT 없음(프록시)
question.setWorksheet(ref);   // FK 연결만 할 거면 충분 — 조회 비용 절약
```

> 💡 **정리**: findById=즉시 조회, getReference=프록시만. FK 연결 등 PK만 필요할 때 후자가 유리.

---

### Q5. OSIV를 false로 두면 코드에서 뭘 신경 써야 하나요?

Service 계층(=트랜잭션 안)에서 **필요한 연관 데이터를 모두 초기화하거나 DTO로 변환**해 반환해야 한다. Controller로 Entity를 그대로 넘기고 거기서 LAZY를 건드리면 예외가 난다. 즉 "트랜잭션 안에서 화면에 필요한 데이터를 완성해 내보낸다"는 설계가 강제된다 — 오히려 좋은 습관이다.

```java
@Transactional(readOnly = true)
public WorksheetDetailDto.Response getWorksheet(Long id) {
    DbankWorksheet ws = queryRepository.selectWorksheetById(id);
    return WorksheetDetailDto.Response.of(ws);  // 트랜잭션 안에서 DTO로 완성
}
```

> 💡 **정리**: OSIV false면 Service 안에서 DTO로 변환해 내보낸다 — LAZY를 Controller까지 끌고 가지 않는다.
