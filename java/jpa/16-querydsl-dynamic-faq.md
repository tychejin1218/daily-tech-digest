### Q1. 동적 WHERE는 BooleanBuilder와 BooleanExpression 중 뭘 쓰나요?

조건이 적으면 둘 다 괜찮지만, 조건이 늘수록 **BooleanExpression**이 낫다. `if`로 누적하는 BooleanBuilder는 조건이 5개만 돼도 가독성이 무너진다. BooleanExpression은 조건을 메서드로 분리해 `where(...)`에 나열하면 되고, 그 메서드를 다른 쿼리에서 재사용할 수 있다.

```java
.where(w.isDeleted.eq(false),
       nameContains(req.getKeyword()),   // 메서드로 분리·재사용
       createdByEq(req.getCreatedBy()))
```

> 💡 **정리**: 조건이 늘면 BooleanExpression(메서드 분리+재사용)이 BooleanBuilder보다 유리.

---

### Q2. `where(...)`에 null을 넘겨도 안전하다는 게 무슨 뜻인가요?

`where(a, b, c)`의 가변인자 중 **null인 항목은 자동으로 빠지고** 나머지가 AND로 연결된다는 뜻이다. 그래서 "값이 있으면 조건 추가, 없으면 null 반환"하는 메서드를 만들면 if 분기 없이 동적 조건이 된다. 단, 모든 인자가 null이면 조건이 전혀 없는 전체 조회가 되므로 기본 조건 하나는 두는 게 안전하다.

```java
private BooleanExpression nameContains(String kw) {
    return kw != null ? w.worksheetName.contains(kw) : null;  // null → 조건 제외
}
```

> 💡 **정리**: where 가변인자의 null은 빠지고 나머지는 AND. 전체 null이면 전체 조회되니 주의.

---

### Q3. 정렬 기준이 화면마다 달라질 때 어떻게 처리하나요?

컬럼마다 `if`로 분기하면 컬럼이 늘 때마다 코드가 폭증한다. `PathBuilder`로 필드명을 동적 경로로 만들고 `OrderSpecifier`로 변환하면, Spring의 `Pageable.getSort()`(=`?sort=field,dir`)를 그대로 QueryDSL 정렬로 옮길 수 있어 컬럼이 추가돼도 코드 수정이 없다.

```java
PathBuilder<DbankWorksheet> path = new PathBuilder<>(DbankWorksheet.class, "dbankWorksheet");
new OrderSpecifier(order.isAscending() ? Order.ASC : Order.DESC, path.get(order.getProperty()));
```

> 💡 **정리**: PathBuilder+OrderSpecifier로 Pageable의 sort를 동적 정렬로 변환한다.

---

### Q4. PathBuilder로 정렬 컬럼을 동적으로 받으면 위험하진 않나요?

위험할 수 있다. 클라이언트가 보낸 `sort` 문자열을 그대로 `path.get(...)`에 넘기면, 존재하지 않거나 노출하면 안 되는 필드명이 들어와 예외나 의도치 않은 정렬이 될 수 있다. 그래서 **정렬 허용 컬럼을 화이트리스트로 검증**한 뒤 통과한 값만 PathBuilder에 넘기는 게 안전하다.

```java
Set<String> allowed = Set.of("createdAt", "worksheetName", "id");
if (!allowed.contains(order.getProperty())) throw new IllegalArgumentException();
```

> 💡 **정리**: 동적 정렬 필드는 화이트리스트로 검증 후 PathBuilder에 넘긴다.

---

### Q5. BooleanExpression들을 OR로 묶거나 조합하려면 어떻게 하나요?

`expr1.or(expr2)`, `expr1.and(expr2)`로 체이닝한다. 다만 동적 조건 메서드가 **null을 반환할 수 있으면** 거기에 `.or()`를 호출하는 순간 NPE가 난다. OR 조합이 필요하면 null이 끼지 않게 가드를 두거나, 조건이 모두 채워지는 게 보장될 때만 직접 체이닝한다.

```java
BooleanExpression cond = nameContains(kw);
cond = (cond == null) ? descContains(kw) : cond.or(descContains(kw));  // null 안전 OR
```

> 💡 **정리**: or()/and()로 조합하되, null 반환 조건에 직접 .or()하면 NPE — null 가드를 둔다.
