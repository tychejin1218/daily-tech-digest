### 1. DTO 조회 (Projection) — Entity 대신 필요한 데이터만 가져오기

Entity를 통째로 조회하면 불필요한 컬럼까지 SELECT하고, 영속성 컨텍스트에 등록되어 메모리를 차지한다. **조회 전용 API에서는 DTO로 필요한 필드만 직접 조회**하면 SELECT 컬럼이 줄고, 영속성 컨텍스트를 거치지 않아 성능이 향상된다.

```java
// ❌ Entity 조회 — 모든 컬럼 SELECT + 영속성 컨텍스트 등록
@Transactional(readOnly = true)
public List<DbankWorksheet> getWorksheetList() {
    return worksheetRepository.findAll();
    // SELECT id, worksheet_name, is_deleted, created_by, modified_by,
    //        deleted_by, created_at, modified_at, deleted_at ... (전체 컬럼)
}

// ✅ DTO 조회 — 필요한 컬럼만 SELECT + 영속성 컨텍스트 미등록
@Transactional(readOnly = true)
public List<WorksheetListDto> getWorksheetList() {
    return queryFactory
        .select(Projections.constructor(WorksheetListDto.class,
            worksheet.id,
            worksheet.worksheetName,
            worksheet.createdAt
        ))
        .from(worksheet)
        .where(worksheet.isDeleted.eq(false))
        .fetch();
    // SELECT id, worksheet_name, created_at (3개만)
}
```

**QueryDSL Projection 방식 3가지:**

```java
// 1. Projections.constructor — 생성자 기반 (가장 많이 사용)
queryFactory
    .select(Projections.constructor(WorksheetListDto.class,
        worksheet.id,
        worksheet.worksheetName))
    .from(worksheet).fetch();

// 2. Projections.fields — 필드 직접 주입 (필드명 일치 필요)
queryFactory
    .select(Projections.fields(WorksheetListDto.class,
        worksheet.id,
        worksheet.worksheetName))
    .from(worksheet).fetch();

// 3. @QueryProjection — 컴파일 타임 타입 검증 (가장 안전)
public class WorksheetListDto {
    @QueryProjection  // QWorksheetListDto 생성됨
    public WorksheetListDto(Long id, String worksheetName) { ... }
}
queryFactory
    .select(new QWorksheetListDto(worksheet.id, worksheet.worksheetName))
    .from(worksheet).fetch();
```

> 💡 **왜 중요한가**: 목록 조회 API에서 Entity를 통째로 조회하면 불필요한 컬럼과 영속성 컨텍스트 비용이 발생하며, DTO 직접 조회는 네트워크 전송량과 메모리 사용량을 모두 줄여 대량 데이터 조회 성능을 크게 개선한다.

---

### 2. Pageable — Spring Data JPA 페이징과 QueryDSL 연동

Spring Data JPA의 `Pageable`을 사용하면 페이징과 정렬을 표준화된 방식으로 처리할 수 있다. Controller에서 `?page=0&size=20&sort=id,desc` 파라미터를 자동으로 `Pageable` 객체로 변환하며, QueryDSL과 연동하면 동적 쿼리에서도 일관된 페이징을 적용할 수 있다.

```java
// Controller — Pageable 자동 바인딩
@GetMapping("/worksheets")
public Page<WorksheetListDto> list(
    @RequestParam(required = false) String keyword,
    Pageable pageable  // ?page=0&size=20&sort=id,desc → 자동 변환
) {
    return worksheetService.getWorksheetList(keyword, pageable);
}
```

```java
// QueryDSL + Pageable 연동
public Page<WorksheetListDto> getWorksheetList(String keyword, Pageable pageable) {
    QDbankWorksheet worksheet = QDbankWorksheet.dbankWorksheet;

    // 데이터 조회
    List<WorksheetListDto> content = queryFactory
        .select(Projections.constructor(WorksheetListDto.class,
            worksheet.id,
            worksheet.worksheetName,
            worksheet.createdAt))
        .from(worksheet)
        .where(
            worksheet.isDeleted.eq(false),
            keyword != null ? worksheet.worksheetName.contains(keyword) : null
        )
        .orderBy(worksheet.id.desc())
        .offset(pageable.getOffset())   // (page * size)
        .limit(pageable.getPageSize())   // size
        .fetch();

    // 전체 건수 조회 (별도 COUNT 쿼리)
    Long total = queryFactory
        .select(worksheet.count())
        .from(worksheet)
        .where(
            worksheet.isDeleted.eq(false),
            keyword != null ? worksheet.worksheetName.contains(keyword) : null
        )
        .fetchOne();

    return new PageImpl<>(content, pageable, total != null ? total : 0L);
}
```

```
요청: GET /worksheets?page=2&size=10&sort=id,desc

Pageable 객체:
  page = 2          → offset = 2 * 10 = 20
  size = 10         → limit = 10
  sort = id DESC

실행 SQL:
  SELECT id, worksheet_name, created_at
  FROM dbank_worksheet
  WHERE is_deleted = false
  ORDER BY id DESC
  LIMIT 10 OFFSET 20;

  SELECT COUNT(*) FROM dbank_worksheet WHERE is_deleted = false;
```

> 💡 **왜 중요한가**: 페이징에서 COUNT 쿼리는 데이터가 많을수록 성능 부담이 되므로, 전체 건수가 필요 없는 무한 스크롤 UI에서는 `Slice`를 사용하거나 COUNT 쿼리를 생략하는 최적화를 고려해야 한다.