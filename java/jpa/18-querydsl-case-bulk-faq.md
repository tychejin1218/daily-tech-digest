### Q1. `CaseBuilder`는 어떤 상황에 쓰나요?

SQL의 `CASE WHEN`을 자바로 표현할 때 쓴다. 컬럼값을 라벨로 바꾸거나(예: 상태 → "삭제됨/신규/일반"), 정렬 우선순위를 부여하거나, 조건부 집계를 할 때 유용하다. SELECT·ORDER BY·WHERE 어디에든 표현식으로 끼울 수 있다.

```java
StringExpression label = new CaseBuilder()
    .when(w.isDeleted.eq(true)).then("삭제됨")
    .otherwise("일반");
```

> 💡 **정리**: CaseBuilder는 CASE WHEN을 자바로 — 라벨링/우선순위/조건부 집계에 쓴다.

---

### Q2. "관리자 글을 항상 맨 위로" 같은 정렬을 컬럼 추가 없이 할 수 있나요?

있다. `CaseBuilder`로 가상의 **우선순위 숫자**를 만들어 그걸로 정렬하면, DB에 정렬 전용 컬럼을 두지 않아도 된다. 우선순위를 1·2·3으로 부여하고 그다음 보조 정렬(생성일 등)을 이어 붙인다.

```java
NumberExpression<Integer> priority = new CaseBuilder()
    .when(w.createdBy.eq("admin")).then(1)
    .otherwise(2);
queryFactory.selectFrom(w).orderBy(priority.asc(), w.createdAt.desc()).fetch();
```

> 💡 **정리**: CaseBuilder로 가상 우선순위를 만들어 정렬하면 정렬용 컬럼이 필요 없다.

---

### Q3. QueryDSL `update()`/`delete()`가 변경 감지보다 빠른 이유와 함정은?

변경 감지는 건마다 SELECT+UPDATE를 날리지만, 벌크는 **단일 UPDATE/DELETE**로 끝나 1만 건도 한 방이다. 대신 영속성 컨텍스트를 거치지 않아 DB는 바뀌었는데 캐시 속 Entity는 옛 값 그대로 남는다. 그래서 속도를 얻는 대신 **컨텍스트 동기화 책임이 개발자에게** 넘어온다.

```java
long n = queryFactory.update(w).set(w.isDeleted, true)
    .where(w.createdAt.lt(cutoff)).execute();   // 단일 UPDATE
```

> 💡 **정리**: 벌크는 단일 쿼리라 빠르지만 영속성 컨텍스트를 우회 — 동기화는 직접 챙겨야 한다.

---

### Q4. QueryDSL 벌크 연산 뒤에 `em.flush()`/`em.clear()`를 왜 호출하나요?

`flush()`는 혹시 컨텍스트에 남은 변경을 DB에 먼저 반영해 순서를 맞추고(보통 비어있지만 관행), `clear()`는 **1차 캐시를 비워** 이후 조회가 DB의 최신값을 새로 읽게 한다. 핵심은 `clear()`다 — 안 하면 벌크로 바뀐 데이터를 옛 캐시 값으로 잘못 조회한다. (Spring Data의 `@Modifying`은 `clearAutomatically = true`로 이걸 자동화한다.)

```java
queryFactory.update(w)....execute();
em.flush();
em.clear();   // ★ 이후 조회가 DB 최신값을 읽도록 캐시 비우기
```

> 💡 **정리**: 벌크 후 em.clear()로 캐시를 비워야 DB와 불일치를 막는다(@Modifying은 clearAutomatically로 자동).

---

### Q5. 조건부 집계(예: 활성 건수만 카운트)는 어떻게 하나요?

`CaseBuilder`로 조건에 맞으면 1, 아니면 0을 주고 `.sum()`하면 조건부 카운트가 된다. `GROUP BY`와 함께 쓰면 그룹별 활성 건수 같은 통계를 한 쿼리로 뽑을 수 있다.

```java
.select(w.createdBy,
    new CaseBuilder().when(w.isDeleted.eq(false)).then(1).otherwise(0).sum().as("activeCount"))
.from(w).groupBy(w.createdBy).fetch();
```

> 💡 **정리**: CASE로 1/0을 만들어 sum()하면 조건부 집계가 된다(GROUP BY와 조합).
