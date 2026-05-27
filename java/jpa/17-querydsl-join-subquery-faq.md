### Q1. Left Join에서 자식 테이블 조건은 `on`과 `where` 중 어디에 넣나요?

의도에 따라 다르다. **자식만 필터링하고 부모는 다 보고 싶으면 `on`절**에, 부모까지 거르려면 `where`에 둔다. Left Join에서 자식 조건을 `where`에 넣으면 매칭 안 된 부모 행(자식이 null)까지 빠져 **Inner Join처럼** 동작해버린다.

```java
.leftJoin(w.questions, q).on(q.isDeleted.eq(false))  // worksheet은 전부, question은 미삭제만
.where(w.isDeleted.eq(false))                         // worksheet 필터
```

> 💡 **정리**: Left Join에서 자식 필터는 on절, 부모 필터는 where절. where에 자식 조건 넣으면 inner가 된다.

---

### Q2. `fetchJoin()`과 그냥 `join()`은 뭐가 다른가요?

일반 `join()`은 조인 조건/필터에만 쓰이고 연관 Entity를 **영속성 컨텍스트에 채우지 않는다**. 그래서 조인해도 자식 접근 시 LAZY 쿼리가 또 나간다. `fetchJoin()`은 연관 Entity까지 함께 조회해 초기화하므로 N+1을 막는다(단 컬렉션 fetchJoin + 페이징은 메모리 페이징 주의).

```java
.leftJoin(w.questions, q).fetchJoin()   // questions까지 한 번에 로딩
```

> 💡 **정리**: 자식까지 로딩하려면 fetchJoin(). 일반 join()은 조인만 하고 LAZY는 그대로.

---

### Q3. 연관관계 매핑이 없는 두 Entity를 조인하려면 어떻게 하나요?

**세타 조인**을 쓴다. `from()`에 두 Entity를 모두 두고 `where`로 공통 컬럼을 묶으면, FK 매핑이 없어도 조인이 된다. 다만 일반 세타 조인은 outer join이 안 되므로, outer가 필요하면 `leftJoin(...).on(...)`의 on절 조인을 쓴다.

```java
.select(w, u)
.from(w, u)                        // 연관 매핑 없는 두 Entity
.where(w.createdBy.eq(u.userId))   // 컬럼 일치로 조인
```

> 💡 **정리**: 매핑 없는 조인은 from에 둘 다 두는 세타 조인. outer가 필요하면 on절 조인.

---

### Q4. QueryDSL로 FROM절 서브쿼리(인라인 뷰)를 짰더니 안 되던데요?

JPA 표준이 **FROM절 서브쿼리를 지원하지 않기** 때문이다(SELECT/WHERE절 서브쿼리는 가능). 인라인 뷰가 꼭 필요하면 ①두 번 나눠 조회해 애플리케이션에서 조립하거나, ②`nativeQuery`로 우회한다.

```java
// WHERE절 서브쿼리는 가능 — 질문 5개 이상인 worksheet
.where(JPAExpressions.select(q.count()).from(q).where(q.worksheet.eq(w)).goe(5L))
```

> 💡 **정리**: JPA는 FROM절 서브쿼리 미지원. 분할 조회나 네이티브 쿼리로 우회한다.

---

### Q5. 서브쿼리에서 메인과 같은 Entity를 또 참조하면 별칭이 충돌해요. 어떻게 하나요?

기본 Q인스턴스는 별칭이 같아 메인 쿼리와 서브쿼리에서 동시에 쓰면 충돌한다. 서브쿼리용으로 **별칭을 따로 준 Q인스턴스를 새로 만들어** 쓰면 된다.

```java
QDbankWorksheet wSub = new QDbankWorksheet("wSub");   // 별칭 분리
queryFactory.select(w, JPAExpressions.select(wSub.count()).from(wSub)...);
```

> 💡 **정리**: 같은 Entity를 서브쿼리에서 또 쓰면 new Q("별칭")으로 별칭을 분리한다.
