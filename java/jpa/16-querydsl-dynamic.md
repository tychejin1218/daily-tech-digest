### 1. BooleanBuilder vs BooleanExpression — 동적 조건 조합 전략 비교

QueryDSL에서 동적 `WHERE` 조건을 만드는 방법은 두 가지다. **BooleanBuilder**는 명령형으로 조건을 누적하는 방식이고, **BooleanExpression**은 메서드로 분리해 선언형으로 조합하는 방식이다. `where()`에 null을 넘기면 해당 조건이 자동 제외되는 특성을 이용해, BooleanExpression이 가독성과 재사용성에서 앞선다.

```java
// ❌ BooleanBuilder — 명령형, 조건이 늘어날수록 복잡
public List<DbankWorksheet> searchByBuilder(WorksheetSearchDto req) {
    QDbankWorksheet w = QDbankWorksheet.dbankWorksheet;
    BooleanBuilder builder = new BooleanBuilder();

    builder.and(w.isDeleted.eq(false));
    if (req.getKeyword() != null) {
        builder.and(w.worksheetName.contains(req.getKeyword()));
    }
    if (req.getCreatedBy() != null) {
        builder.and(w.createdBy.eq(req.getCreatedBy()));
    }
    if (req.getFromDate() != null) {
        builder.and(w.createdAt.goe(req.getFromDate()));
    }
    return queryFactory.selectFrom(w).where(builder).fetch();
}

// ✅ BooleanExpression — 선언형, 메서드 재사용 가능
public List<DbankWorksheet> searchByExpression(WorksheetSearchDto req) {
    QDbankWorksheet w = QDbankWorksheet.dbankWorksheet;
    return queryFactory
        .selectFrom(w)
        .where(
            w.isDeleted.eq(false),
            nameContains(req.getKeyword()),       // null이면 무시
            createdByEq(req.getCreatedBy()),       // null이면 무시
            createdAfter(req.getFromDate())        // null이면 무시
        )
        .fetch();
}

// 조건 메서드 — 다른 쿼리에서도 재사용
private BooleanExpression nameContains(String keyword) {
    return keyword != null ? QDbankWorksheet.dbankWorksheet.worksheetName.contains(keyword) : null;
}
private BooleanExpression createdByEq(String userId) {
    return userId != null ? QDbankWorksheet.dbankWorksheet.createdBy.eq(userId) : null;
}
private BooleanExpression createdAfter(LocalDateTime from) {
    return from != null ? QDbankWorksheet.dbankWorksheet.createdAt.goe(from) : null;
}
```

```
where(...) 가변인자의 null 처리:

queryFactory.where(cond1, null, cond3)
                          ~~~~
                          null은 자동 무시됨

→ 결과 SQL: WHERE cond1 AND cond3
                       ~~~~~~~ null만 빠지고 나머지는 AND로 연결
```

> 💡 **왜 중요한가**: 검색 API에서 조건이 5개 이상 늘어나면 BooleanBuilder의 `if` 블록이 가독성을 무너뜨리므로, BooleanExpression 메서드로 분리해두면 다른 쿼리에서도 그대로 재사용할 수 있어 유지보수 비용이 크게 줄어든다.

---

### 2. OrderSpecifier — 동적 정렬과 다중 정렬 처리

정렬 조건이 화면별로 달라지는 검색 API에서는 `OrderSpecifier`를 동적으로 생성해야 한다. Spring Data의 `Sort` 객체를 QueryDSL의 `OrderSpecifier[]`로 변환하면 Controller의 `?sort=field,direction` 파라미터를 그대로 QueryDSL 쿼리에 적용할 수 있다.

```java
// Sort → OrderSpecifier 변환 유틸
public List<DbankWorksheet> findWithSort(Pageable pageable) {
    QDbankWorksheet w = QDbankWorksheet.dbankWorksheet;

    OrderSpecifier<?>[] orders = pageable.getSort().stream()
        .map(order -> {
            Order direction = order.isAscending() ? Order.ASC : Order.DESC;
            PathBuilder<DbankWorksheet> path =
                new PathBuilder<>(DbankWorksheet.class, "dbankWorksheet");
            return new OrderSpecifier(direction, path.get(order.getProperty()));
        })
        .toArray(OrderSpecifier[]::new);

    return queryFactory
        .selectFrom(w)
        .where(w.isDeleted.eq(false))
        .orderBy(orders)        // 가변인자로 다중 정렬
        .fetch();
}
```

```java
// 정적 다중 정렬 — 우선순위가 명확할 때
public List<DbankWorksheet> findOrdered() {
    QDbankWorksheet w = QDbankWorksheet.dbankWorksheet;
    return queryFactory
        .selectFrom(w)
        .orderBy(
            w.createdAt.desc(),           // 1순위: 최근 생성순
            w.worksheetName.asc().nullsLast()  // 2순위: 이름순 (null은 뒤로)
        )
        .fetch();
}
```

```
요청: GET /worksheets?sort=createdAt,desc&sort=worksheetName,asc

Pageable.getSort():
  [createdAt: DESC, worksheetName: ASC]
                ↓ 변환
OrderSpecifier[]:
  [createdAt DESC, worksheetName ASC]
                ↓ 실행
SQL:
  ORDER BY created_at DESC, worksheet_name ASC
```

> 💡 **왜 중요한가**: 정렬 파라미터를 문자열 비교(`if "createdAt".equals(sort)`)로 분기하면 컬럼이 늘 때마다 분기가 폭증하므로, `PathBuilder`로 동적 경로를 만들어두면 정렬 가능 컬럼이 추가돼도 코드 수정 없이 동작한다.
