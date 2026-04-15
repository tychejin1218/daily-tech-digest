### 1. JPQL — Entity 기반 쿼리 언어의 기본 문법과 사용법

JPQL(Java Persistence Query Language)은 SQL과 비슷하지만 **테이블이 아닌 Entity를 대상으로 쿼리**하는 언어다. `@Query` 어노테이션으로 Repository에서 사용하며, 컴파일 시점에 문법 오류를 잡아준다. 테이블명 대신 Entity 클래스명, 컬럼명 대신 필드명을 사용한다.

```java
public interface WorksheetRepository extends JpaRepository<DbankWorksheet, Long> {

    // JPQL — Entity 필드명 사용 (worksheetName, isDeleted)
    @Query("SELECT w FROM DbankWorksheet w WHERE w.worksheetName = :name AND w.isDeleted = false")
    List<DbankWorksheet> findByName(@Param("name") String name);

    // Native SQL — 테이블 컬럼명 사용 (worksheet_name, is_deleted)
    @Query(value = "SELECT * FROM dbank_worksheet WHERE worksheet_name = :name AND is_deleted = 0",
           nativeQuery = true)
    List<DbankWorksheet> findByNameNative(@Param("name") String name);
}
```

```
JPQL vs SQL 비교:

JPQL:   SELECT w FROM DbankWorksheet w WHERE w.worksheetName = :name
                      ~~~~~~~~~~~~~~~         ~~~~~~~~~~~~~~
                      Entity 클래스명           필드명

SQL:    SELECT * FROM dbank_worksheet WHERE worksheet_name = ?
                      ~~~~~~~~~~~~~~~       ~~~~~~~~~~~~~~
                      테이블명                 컬럼명
```

```java
// Fetch Join — N+1 방지
@Query("SELECT w FROM DbankWorksheet w " +
       "JOIN FETCH w.questions q " +       // LAZY여도 한 번에 조회
       "WHERE w.id = :id AND w.isDeleted = false")
Optional<DbankWorksheet> findByIdWithQuestions(@Param("id") Long id);

// DTO 직접 조회 — Entity 대신 필요한 필드만
@Query("SELECT new com.example.dto.WorksheetSummary(w.id, w.worksheetName, COUNT(q)) " +
       "FROM DbankWorksheet w LEFT JOIN w.questions q " +
       "WHERE w.isDeleted = false GROUP BY w.id")
List<WorksheetSummary> findSummaries();
```

> 💡 **왜 중요한가**: JPQL은 DB 벤더에 독립적이고 Entity 필드명을 사용해 타입 안전성이 높지만, 문자열 기반이라 복잡한 동적 쿼리에는 한계가 있어 QueryDSL과 역할을 나눠 사용하는 것이 효과적이다.

---

### 2. QueryDSL — 타입 안전한 동적 쿼리 작성

QueryDSL은 **자바 코드로 SQL을 작성**하는 프레임워크로, 컴파일 시점에 필드명 오타나 타입 불일치를 잡아준다. JPQL의 문자열 기반 쿼리와 달리 IDE 자동완성이 지원되며, 조건을 동적으로 조합할 수 있어 검색/필터링 API에 필수적이다.

```java
// QueryDSL — 기본 조회
@Repository
@RequiredArgsConstructor
public class WorksheetQueryRepository {

    private final JPAQueryFactory queryFactory;

    public List<DbankWorksheet> selectWorksheetList(WorksheetSearchDto request) {
        QDbankWorksheet worksheet = QDbankWorksheet.dbankWorksheet;

        return queryFactory
            .selectFrom(worksheet)
            .where(
                worksheet.isDeleted.eq(false),
                worksheet.createdBy.eq(request.getUserId()),
                worksheetNameContains(request.getKeyword())  // 동적 조건
            )
            .orderBy(worksheet.id.desc())
            .offset(request.getOffset())
            .limit(request.getLimit())
            .fetch();
    }

    // 동적 조건 — null이면 조건 자체가 제외됨
    private BooleanExpression worksheetNameContains(String keyword) {
        return keyword != null
            ? QDbankWorksheet.dbankWorksheet.worksheetName.contains(keyword)
            : null;  // where절에서 null은 무시됨
    }
}
```

```
JPQL vs QueryDSL 비교:

| 항목         | JPQL (@Query)      | QueryDSL              |
|-------------|--------------------|-----------------------|
| 작성 방식     | 문자열              | Java 코드              |
| 컴파일 검증   | 앱 로딩 시 검증       | 컴파일 시 즉시 검증       |
| 동적 쿼리     | 문자열 연결 (지저분)  | BooleanExpression 조합  |
| IDE 지원     | 자동완성 제한         | 완벽한 자동완성           |
| 사용 시점     | 단순 조회, Fetch Join | 검색, 필터링, 복잡한 조건  |
```

```java
// 프로젝트 패턴 — Repository 역할 분리
// 1. JpaRepository — 기본 CRUD + 간단한 쿼리 메서드
public interface WorksheetRepository extends JpaRepository<DbankWorksheet, Long> {
    Optional<DbankWorksheet> findByIdAndIsDeletedFalse(Long id);
}

// 2. QueryRepository — QueryDSL 동적 쿼리
@Repository
public class WorksheetQueryRepository {
    // 검색, 필터링, 복잡한 JOIN, 페이징 등
}
```

> 💡 **왜 중요한가**: 검색 조건이 동적으로 바뀌는 API에서 JPQL로 문자열을 조합하면 가독성과 유지보수성이 급격히 떨어지며, QueryDSL의 `BooleanExpression`을 활용하면 조건을 메서드로 분리해 재사용할 수 있다.