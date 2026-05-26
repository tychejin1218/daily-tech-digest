### 1. QueryDSL Join 종류 — innerJoin / leftJoin / fetchJoin / on절 활용

QueryDSL은 SQL의 거의 모든 조인 형태를 지원한다. 연관 매핑이 있는 경우 `join(entity.relation, target)`으로, 연관 없는 두 Entity는 `from()`에 둘 다 두고 `where`로 묶는 **세타 조인**으로 처리한다. `on`절은 조인 자체에 조건을 거는 용도로, `where`에서 거를 때와 결과가 다르다.

```java
// 1. Inner Join — 양쪽에 데이터가 있어야 결과 반환
QDbankWorksheet w = QDbankWorksheet.dbankWorksheet;
QDbankWorksheetQuestion q = QDbankWorksheetQuestion.dbankWorksheetQuestion;

queryFactory
    .selectFrom(w)
    .innerJoin(w.questions, q)
    .where(w.isDeleted.eq(false))
    .fetch();

// 2. Left Join + on절 — 조인 자체에 조건 (worksheet은 모두, question은 미삭제만)
queryFactory
    .selectFrom(w)
    .leftJoin(w.questions, q).on(q.isDeleted.eq(false))   // ← question 조건만
    .where(w.isDeleted.eq(false))                          // ← worksheet 조건
    .fetch();

// 3. Fetch Join — N+1 방지, LAZY 컬렉션을 한 번에 로딩
queryFactory
    .selectFrom(w)
    .leftJoin(w.questions, q).fetchJoin()
    .where(w.id.eq(worksheetId))
    .fetchOne();

// 4. 세타 조인 — 연관관계 없는 두 Entity
QUser u = QUser.user;
queryFactory
    .select(w, u)
    .from(w, u)                              // from에 둘 다
    .where(w.createdBy.eq(u.userId))         // FK 없이 컬럼만 일치
    .fetch();
```

```
on절 vs where절 차이 (Left Join 기준):

[on절 조건]                          [where절 조건]
LEFT JOIN q ON w.id=q.wid            LEFT JOIN q ON w.id=q.wid
            AND q.is_deleted=false   WHERE q.is_deleted=false

worksheet은 모두 반환,                worksheet도 필터됨
question은 미삭제만 매칭              (q가 null인 행이 제외돼 INNER처럼 동작)
```

> 💡 **왜 중요한가**: Left Join에서 자식 테이블 조건을 `where`에 넣으면 매칭 안 된 부모 행까지 사라져 Inner Join처럼 동작하므로, 자식 필터링 의도라면 반드시 `on`절에 조건을 두고 부모 필터링은 `where`로 분리해야 한다.

---

### 2. Subquery — JPAExpressions로 SELECT/WHERE/FROM절 서브쿼리

QueryDSL의 서브쿼리는 `JPAExpressions` 정적 메서드로 작성한다. SELECT절·WHERE절에서 모두 사용 가능하지만 **JPA 표준은 FROM절 서브쿼리(인라인 뷰)를 지원하지 않는다**는 점에 주의해야 한다. 같은 Entity를 두 번 참조할 때는 별도 Q인스턴스(`new QDbankWorksheet("subWorksheet")`)를 만들어 별칭 충돌을 피한다.

```java
import static com.querydsl.jpa.JPAExpressions.*;

QDbankWorksheet w = QDbankWorksheet.dbankWorksheet;
QDbankWorksheetQuestion q = QDbankWorksheetQuestion.dbankWorksheetQuestion;

// 1. WHERE절 서브쿼리 — 질문이 5개 이상인 worksheet만
queryFactory
    .selectFrom(w)
    .where(
        select(q.count())
            .from(q)
            .where(q.worksheet.eq(w))
            .goe(5L)
    )
    .fetch();

// 2. WHERE IN 서브쿼리 — 특정 사용자가 만든 worksheet의 질문들
queryFactory
    .selectFrom(q)
    .where(q.worksheet.id.in(
        select(w.id)
            .from(w)
            .where(w.createdBy.eq("user-123"))
    ))
    .fetch();

// 3. SELECT절 서브쿼리 — Entity와 함께 카운트 노출
QDbankWorksheet wSub = new QDbankWorksheet("wSub");   // 별칭 충돌 방지
queryFactory
    .select(w, select(q.count()).from(q).where(q.worksheet.eq(w)))
    .from(w)
    .where(w.isDeleted.eq(false))
    .fetch();
```

```
서브쿼리 사용 가능 위치 (JPA 표준):

SELECT (서브쿼리)  ← ✅ JPAExpressions.select(...)
FROM   (서브쿼리)  ← ❌ JPA 표준 미지원 — 네이티브 쿼리 필요
WHERE  (서브쿼리)  ← ✅ in / exists / >= / <= 등 자유

대안: FROM절 서브쿼리가 꼭 필요하면 → 두 번 쿼리해서 애플리케이션에서 조립
       또는 → @Query(nativeQuery=true)로 우회
```

> 💡 **왜 중요한가**: 통계 화면에서 "각 worksheet별 질문 수" 같은 집계를 매번 JOIN+GROUP BY로 풀면 쿼리가 무거워질 수 있는데, SELECT절 서브쿼리로 분리하면 의도가 명확해지고 메인 쿼리의 카디널리티가 부풀지 않는다.
