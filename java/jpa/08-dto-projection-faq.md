### Q1. 조회할 때 Entity 대신 DTO로 가져오면 왜 더 빠른가요?

두 가지 이득이 있다. ①SELECT하는 **컬럼 수가 줄어** 네트워크 전송량이 작아지고, ②조회 결과가 **영속성 컨텍스트에 등록되지 않아** 스냅샷 저장·Dirty Checking 대상에서 빠진다. 변경할 일 없는 목록 조회에서는 DTO 직접 조회가 메모리와 시간을 모두 아낀다.

```java
.select(Projections.constructor(WorksheetListDto.class,
    worksheet.id, worksheet.worksheetName, worksheet.createdAt))  // 3컬럼만, 영속 아님
.from(worksheet).where(worksheet.isDeleted.eq(false)).fetch();
```

> 💡 **정리**: DTO 조회는 컬럼 수↓ + 영속성 컨텍스트 미등록 → 조회 전용 API에 최적.

---

### Q2. QueryDSL Projection 세 가지(constructor/fields/@QueryProjection)는 어떻게 고르나요?

`constructor`는 생성자 인자 순서·타입만 맞으면 되고 가장 무난하다. `fields`는 setter/필드명이 일치해야 주입된다. `@QueryProjection`은 DTO 생성자에 붙여 Q타입을 만들어 **컴파일 시점에 타입까지 검증**되지만, DTO가 QueryDSL에 의존하게 되는 단점이 있다. 안전성이 중요하면 @QueryProjection, 의존성을 피하려면 constructor를 쓴다.

```java
.select(new QWorksheetListDto(worksheet.id, worksheet.worksheetName))  // @QueryProjection
```

> 💡 **정리**: 무난하면 constructor, 컴파일 검증이 중요하면 @QueryProjection(단 의존성 생김).

---

### Q3. DTO로 조회한 객체는 값을 바꿔도 UPDATE가 안 되던데요?

의도된 동작이다. DTO는 Entity가 아니라 **영속성 컨텍스트가 관리하지 않는 일반 객체**다. 스냅샷도 없고 Dirty Checking 대상도 아니므로 값을 바꿔도 DB에 반영되지 않는다. 변경이 목적이면 DTO가 아니라 Entity를 조회해야 한다.

> 💡 **정리**: DTO는 비영속 객체 — 조회 전용. 변경하려면 Entity를 조회한다.

---

### Q4. `Page`와 `Slice`는 뭐가 다른가요?

`Page`는 데이터 목록 + **전체 건수(COUNT 쿼리)**를 함께 제공해 "전체 N페이지" UI에 쓴다. `Slice`는 전체 건수를 구하지 않고 "다음 페이지가 있는지"만 판단(size+1건 조회)해 **무한 스크롤**에 적합하다. COUNT 쿼리가 빠지므로 데이터가 많을 때 더 가볍다.

```java
Page<WorksheetListDto>  list(..., Pageable p);   // content + totalCount
Slice<WorksheetListDto> scroll(..., Pageable p); // content + hasNext (COUNT 없음)
```

> 💡 **정리**: 전체 페이지 수가 필요하면 Page, 무한 스크롤이면 Slice(COUNT 생략).

---

### Q5. 페이징 COUNT 쿼리가 부담될 때 어떻게 최적화하나요?

몇 가지가 있다. ①무한 스크롤이면 `Slice`로 COUNT 자체를 생략, ②`PageableExecutionUtils`로 마지막 페이지 등에서 불필요한 COUNT 호출을 건너뛰기, ③COUNT 쿼리에서는 정렬·fetch join을 빼서 가볍게 만들기다. 데이터 양과 join 복잡도에 따라 COUNT가 본 쿼리보다 비싸질 수 있어 따로 관리하는 게 좋다.

```java
return PageableExecutionUtils.getPage(content, pageable,
    () -> countQuery.fetchOne());  // 필요할 때만 COUNT 실행
```

> 💡 **정리**: COUNT는 본 쿼리와 분리해 가볍게 짜고, 가능하면 Slice나 지연 실행으로 생략한다.
