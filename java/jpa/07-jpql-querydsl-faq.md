### Q1. JPQL과 네이티브 쿼리는 뭐가 다르고, 네이티브는 언제 쓰나요?

JPQL은 **Entity와 필드명**을 대상으로 쿼리해 DB 벤더에 독립적이고, 네이티브 쿼리는 실제 **테이블·컬럼명**으로 raw SQL을 쓴다. 윈도우 함수, DB 전용 힌트, 복잡한 통계처럼 JPQL로 표현이 안 되는 경우에만 `nativeQuery = true`를 쓰고, 평소엔 JPQL/QueryDSL을 우선한다.

```java
@Query("SELECT w FROM DbankWorksheet w WHERE w.isDeleted = false")          // JPQL
@Query(value = "SELECT * FROM dbank_worksheet WHERE is_deleted = 0",
       nativeQuery = true)                                                   // Native
```

> 💡 **정리**: 기본은 JPQL(벤더 독립), DB 전용 기능이 필요할 때만 native.

---

### Q2. JPQL은 문자열인데 "컴파일 시 검증"된다는 게 사실인가요?

정확히는 순수 JPQL 문자열의 문법 오류는 **컴파일이 아니라 앱 로딩(SessionFactory 초기화) 시점**에 잡힌다. "컴파일 시점에 잡힌다"는 건 QueryDSL의 Q타입처럼 자바 코드로 작성할 때의 얘기다. 그래서 문자열 오타를 진짜 컴파일 단계에서 막고 싶으면 QueryDSL을 쓰는 게 맞다.

> 💡 **정리**: JPQL 문자열 오류는 앱 로딩 시 발견. 진짜 컴파일 검증은 QueryDSL의 몫.

---

### Q3. QueryDSL 동적 조건 메서드가 null을 반환하면 쿼리가 깨지지 않나요?

깨지지 않는다. `where(...)`에 넘긴 인자 중 **null은 조건에서 자동으로 무시**된다. 그래서 검색어가 없으면 null을 반환하는 `BooleanExpression` 메서드를 만들어 두면, 파라미터 유무에 따라 조건이 동적으로 붙고 빠진다.

```java
private BooleanExpression nameContains(String kw) {
    return kw != null ? worksheet.worksheetName.contains(kw) : null; // null이면 조건 제외
}
queryFactory.selectFrom(worksheet)
    .where(worksheet.isDeleted.eq(false), nameContains(keyword));
```

> 💡 **정리**: where 인자의 null은 무시된다 — 이게 QueryDSL 동적 쿼리의 핵심 트릭.

---

### Q4. JpaRepository와 별도 QueryRepository를 왜 나누나요?

역할이 다르기 때문이다. 기본 CRUD와 단순 파생 쿼리(`findByIdAndIsDeletedFalse`)는 `JpaRepository`로 충분하지만, 동적 검색·복잡한 조인·페이징은 QueryDSL이 적합하다. QueryDSL 코드를 별도 `@Repository` 클래스(QueryRepository)로 분리하면 인터페이스(JpaRepository)와 구현(QueryDSL)이 섞이지 않아 관리가 깔끔하다.

```java
public interface WorksheetRepository extends JpaRepository<DbankWorksheet, Long> {
    Optional<DbankWorksheet> findByIdAndIsDeletedFalse(Long id);  // 단순
}
@Repository
public class WorksheetQueryRepository { /* QueryDSL 동적 쿼리 */ }
```

> 💡 **정리**: 단순 쿼리는 JpaRepository, 동적·복잡 쿼리는 QueryRepository로 분리한다.

---

### Q5. JPQL에서 `JOIN`과 `JOIN FETCH`는 뭐가 다른가요?

일반 `JOIN`은 조인 조건에만 쓰이고 연관 Entity를 **영속성 컨텍스트에 채워주지 않는다**. 그래서 조인해도 자식에 접근하면 다시 LAZY 쿼리가 나간다. `JOIN FETCH`는 연관 Entity까지 함께 **조회해 초기화**하므로, 그 한 번의 쿼리로 N+1을 막는다.

```java
@Query("SELECT w FROM DbankWorksheet w JOIN FETCH w.questions WHERE w.id = :id")
Optional<DbankWorksheet> findByIdWithQuestions(@Param("id") Long id); // 자식까지 한 번에
```

> 💡 **정리**: 자식까지 채우려면 JOIN이 아니라 JOIN FETCH. N+1 해결의 기본 도구.
