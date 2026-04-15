### 1. N+1 문제 — JPA에서 가장 흔한 성능 이슈와 발생 원리

N+1 문제는 연관 Entity를 조회할 때, 부모 1건 조회(1) + 자식 N건 개별 조회(N)로 총 N+1개의 SQL이 발생하는 현상이다. LAZY 로딩에서 컬렉션에 접근할 때마다 SELECT가 나가는 것이 원인이며, 목록 조회에서 데이터가 늘어날수록 쿼리 수가 선형으로 증가해 심각한 성능 저하를 일으킨다.

```java
// ❌ N+1 발생 — 문제지 10건 조회 시 총 11번 SELECT
@Entity
public class DbankWorksheet {
    @OneToMany(mappedBy = "worksheet", fetch = FetchType.LAZY)
    private List<DbankWorksheetQuestion> questions;
}

List<DbankWorksheet> worksheets = worksheetRepository.findAll();  // 1번: SELECT worksheet
for (DbankWorksheet ws : worksheets) {
    ws.getQuestions().size();  // N번: 각 worksheet마다 SELECT question WHERE worksheet_id = ?
}
// 총 쿼리: 1 + 10 = 11번
```

```
N+1 발생 흐름:

SELECT * FROM dbank_worksheet;                              -- 1번 (부모 10건)
SELECT * FROM dbank_worksheet_question WHERE worksheet_id=1;  -- 2번
SELECT * FROM dbank_worksheet_question WHERE worksheet_id=2;  -- 3번
SELECT * FROM dbank_worksheet_question WHERE worksheet_id=3;  -- 4번
...
SELECT * FROM dbank_worksheet_question WHERE worksheet_id=10; -- 11번
```

**해결 방법 3가지:**

```java
// ✅ 방법 1: Fetch Join (JPQL)
@Query("SELECT w FROM DbankWorksheet w JOIN FETCH w.questions")
List<DbankWorksheet> findAllWithQuestions();
// → SELECT w.*, q.* FROM dbank_worksheet w JOIN dbank_worksheet_question q ON ...
// → 1번의 쿼리로 해결

// ✅ 방법 2: @EntityGraph
@EntityGraph(attributePaths = {"questions"})
List<DbankWorksheet> findAll();

// ✅ 방법 3: default_batch_fetch_size (다음 항목에서 설명)
```

> 💡 **왜 중요한가**: N+1은 개발 중에는 데이터가 적어 발견하기 어렵지만, 운영 환경에서 데이터가 쌓이면 갑자기 수백~수천 개의 쿼리가 발생해 DB를 압박하는 가장 흔한 JPA 성능 이슈다.

---

### 2. default_batch_fetch_size — 설정 한 줄로 N+1 문제 완화하기

`default_batch_fetch_size`는 LAZY 로딩 시 연관 Entity를 개별 조회하지 않고 IN 절로 묶어서 한 번에 조회하게 하는 설정이다. 설정 한 줄로 프로젝트 전체에 적용되므로, Fetch Join을 일일이 작성하지 않아도 N+1 문제를 자동으로 완화할 수 있다.

```yaml
# application.yml
spring:
  jpa:
    properties:
      hibernate:
        default_batch_fetch_size: 100
```

```
설정 전 (N+1):
SELECT * FROM worksheet;                                      -- 1번
SELECT * FROM worksheet_question WHERE worksheet_id = 1;       -- 2번
SELECT * FROM worksheet_question WHERE worksheet_id = 2;       -- 3번
...
SELECT * FROM worksheet_question WHERE worksheet_id = 100;     -- 101번

설정 후 (batch_fetch_size=100):
SELECT * FROM worksheet;                                      -- 1번
SELECT * FROM worksheet_question WHERE worksheet_id IN (1,2,3,...,100);  -- 2번
→ 총 2번으로 해결
```

```java
// Entity 단위로 개별 설정도 가능
@Entity
public class DbankWorksheet {
    @BatchSize(size = 100)  // 이 연관관계만 배치 조회
    @OneToMany(mappedBy = "worksheet")
    private List<DbankWorksheetQuestion> questions;
}
```

**Fetch Join vs batch_fetch_size:**

| 항목 | Fetch Join | batch_fetch_size |
|------|-----------|-----------------|
| 적용 범위 | 쿼리 단위 (명시적) | 프로젝트 전체 (자동) |
| 페이징 | 컬렉션 Fetch Join 시 메모리 페이징 (위험) | 페이징 안전 |
| 쿼리 수 | 1번 | 2~3번 (충분히 빠름) |
| 권장 사용 | xToOne 관계, 페이징 없는 조회 | 기본 설정 + xToMany 관계 |

> 💡 **왜 중요한가**: `default_batch_fetch_size: 100` 한 줄이면 프로젝트 전체의 N+1 문제가 자동으로 완화되며, Fetch Join의 페이징 제약 없이 안전하게 사용할 수 있어 가장 먼저 적용해야 할 설정이다.