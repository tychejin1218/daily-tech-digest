### 1. batch_size + order_inserts/updates — bulk 작업 성능 최적화

Hibernate의 `jdbc.batch_size`를 설정하면 INSERT/UPDATE를 개별 실행하지 않고 JDBC 배치로 묶어 한 번에 전송한다. `order_inserts`와 `order_updates`를 함께 켜야 같은 테이블의 SQL끼리 그룹핑되어 실제 배치 효과를 얻을 수 있다.

```yaml
# application.yml
spring:
  jpa:
    properties:
      hibernate:
        jdbc:
          batch_size: 50              # INSERT/UPDATE를 50개씩 묶어서 전송
          order_inserts: true          # 같은 테이블 INSERT끼리 그룹핑
          order_updates: true          # 같은 테이블 UPDATE끼리 그룹핑
```

```
설정 전:
INSERT INTO worksheet_question (worksheet_id, ...) VALUES (1, ...);  -- 1번
INSERT INTO worksheet_pdf (worksheet_id, ...) VALUES (1, ...);       -- 2번
INSERT INTO worksheet_question (worksheet_id, ...) VALUES (2, ...);  -- 3번
INSERT INTO worksheet_pdf (worksheet_id, ...) VALUES (2, ...);       -- 4번
→ 4번 DB 왕복

설정 후 (batch_size=50 + order_inserts=true):
INSERT INTO worksheet_question (...) VALUES (1,...), (2,...);  -- 1번 (같은 테이블끼리 묶임)
INSERT INTO worksheet_pdf (...) VALUES (1,...), (2,...);       -- 2번
→ 2번 DB 왕복
```

```java
// 소프트 삭제 bulk — batch_size 덕분에 UPDATE도 배치 처리됨
@Transactional
public void deleteWorksheets(WorksheetDeleteDto.Request request) {
    List<DbankWorksheetQuestion> questions = queryRepository
        .selectActiveQuestionsByWorksheetIdList(worksheetIds);

    questions.forEach(q -> q.softDelete(userId));  // 100건 변경

    // 트랜잭션 커밋 시 → UPDATE 100건이 batch_size(50)씩 2번에 나눠 전송
    // order_updates=true이므로 같은 테이블 UPDATE끼리 배치됨
}
```

> 💡 **왜 중요한가**: `batch_size`만 설정하고 `order_inserts/updates`를 빠뜨리면 서로 다른 테이블의 SQL이 섞여 배치가 깨지므로, 세 가지를 반드시 함께 설정해야 bulk 작업 성능이 실제로 향상된다.

---

### 2. in_clause_parameter_padding — IN 절 SQL 캐시 효율 높이기

Hibernate의 `in_clause_parameter_padding`을 활성화하면, IN 절의 파라미터 개수를 2의 거듭제곱(1, 2, 4, 8, 16, 32...)으로 패딩하여 SQL 문자열 종류를 줄인다. DB는 SQL 문자열을 키로 실행 계획을 캐싱하므로, IN 절 파라미터 수가 매번 달라지면 캐시 효율이 떨어진다.

```yaml
# application.yml
spring:
  jpa:
    properties:
      hibernate:
        query:
          in_clause_parameter_padding: true
```

```
설정 전 — IN 절 파라미터 수만큼 서로 다른 SQL 생성:
  WHERE id IN (?)                    -- 1개일 때
  WHERE id IN (?, ?)                 -- 2개일 때
  WHERE id IN (?, ?, ?)              -- 3개일 때
  WHERE id IN (?, ?, ?, ?)           -- 4개일 때
  WHERE id IN (?, ?, ?, ?, ?)        -- 5개일 때
  → 5종류의 SQL → DB 실행 계획 캐시 5개 점유

설정 후 — 2의 거듭제곱으로 패딩:
  WHERE id IN (?)                    -- 1개 → 1로 패딩
  WHERE id IN (?, ?)                 -- 2개 → 2로 패딩
  WHERE id IN (?, ?, ?, ?)           -- 3개 → 4로 패딩 (빈 자리는 기존 값 반복)
  WHERE id IN (?, ?, ?, ?)           -- 4개 → 4로 패딩
  WHERE id IN (?, ?, ?, ?, ?, ?, ?, ?) -- 5개 → 8로 패딩
  → 3종류의 SQL → DB 실행 계획 캐시 절약
```

```java
// default_batch_fetch_size와 조합하면 효과적
// batch_fetch_size=100 설정 시, IN 절에 다양한 개수의 ID가 들어감
// → padding이 없으면 1~100까지 100종류의 SQL이 생성됨
// → padding이 있으면 1,2,4,8,16,32,64,128 → 8종류로 축소
```

> 💡 **왜 중요한가**: `default_batch_fetch_size`와 함께 사용하면 IN 절 SQL 종류가 대폭 줄어들어 DB의 실행 계획 캐시 적중률이 높아지고, 특히 트래픽이 많은 운영 환경에서 DB CPU 사용량을 절감할 수 있다.