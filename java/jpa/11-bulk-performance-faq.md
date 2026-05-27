### Q1. `batch_size`만 켰는데 SQL이 여전히 한 건씩 나가요. 왜죠?

배치로 묶이려면 **같은 테이블의 같은 종류 SQL이 연속**이어야 한다. 서로 다른 테이블의 INSERT가 번갈아 나오면 배치가 끊긴다. 그래서 `order_inserts`/`order_updates`를 함께 켜 같은 테이블 SQL끼리 정렬·그룹핑해야 batch_size가 실제로 효과를 낸다.

```yaml
spring.jpa.properties.hibernate.jdbc.batch_size: 50
spring.jpa.properties.hibernate.order_inserts: true   # 함께 켜야 배치됨
spring.jpa.properties.hibernate.order_updates: true
```

> 💡 **정리**: batch_size + order_inserts/updates는 세트. 정렬이 없으면 배치가 깨진다.

---

### Q2. `@GeneratedValue(IDENTITY)`면 batch insert가 안 된다는데, 우회 방법은?

IDENTITY는 INSERT를 실행해야 PK를 알 수 있어 쓰기 지연이 불가능하므로 JPA의 batch insert가 막힌다. 대량 INSERT 성능이 중요하면 ①PK 생성 전략을 SEQUENCE 계열로 바꾸거나(MySQL은 미지원), ②JPA를 벗어나 `JdbcTemplate.batchUpdate()`로 직접 배치 INSERT하는 방식을 쓴다.

```java
jdbcTemplate.batchUpdate(
    "INSERT INTO dbank_worksheet_question (worksheet_id, ...) VALUES (?, ...)",
    batchArgs);   // 수천 건을 한 번에
```

> 💡 **정리**: MySQL+IDENTITY 대량 INSERT는 JdbcTemplate batch로 우회한다.

---

### Q3. `in_clause_parameter_padding`은 뭘 해결하나요?

IN 절의 파라미터 개수가 매번 달라지면 DB 입장에선 **다른 SQL 문자열**이라 실행 계획 캐시가 파편화된다. 이 옵션을 켜면 파라미터 수를 2의 거듭제곱(1,2,4,8…)으로 패딩해 SQL 종류를 줄이고, 캐시 적중률을 높여 DB CPU를 아낀다. `default_batch_fetch_size`와 함께 쓸 때 특히 효과적이다.

```yaml
spring.jpa.properties.hibernate.query.in_clause_parameter_padding: true
```

> 💡 **정리**: IN 절 파라미터를 2의 거듭제곱으로 패딩해 SQL 종류↓ → 실행 계획 캐시 적중률↑.

---

### Q4. batch_size는 무조건 크게 잡으면 좋은가요?

아니다. 너무 크면 한 번에 메모리에 쌓이는 SQL과 영속성 컨텍스트 부담이 커지고, 실패 시 롤백 단위도 커진다. 보통 **50~100** 정도를 시작점으로 잡고, 실제 데이터·메모리 상황에 맞춰 조정한다. 한 트랜잭션에서 수만 건을 처리한다면 중간에 `flush()`+`clear()`로 컨텍스트를 비워줘야 한다.

> 💡 **정리**: batch_size는 50~100이 무난. 대량이면 주기적 flush/clear로 메모리를 관리한다.

---

### Q5. `order_inserts`/`order_updates`는 구체적으로 무슨 일을 하나요?

한 트랜잭션에서 여러 테이블의 SQL이 섞여 나갈 때, 이를 **테이블별로 모아 정렬**해 같은 테이블의 INSERT/UPDATE가 연속되게 만든다. 그래야 JDBC 드라이버가 연속된 동일 구문을 하나의 배치로 묶을 수 있다. 정렬이 없으면 테이블이 바뀔 때마다 배치가 끊겨 batch_size가 무용지물이 된다.

> 💡 **정리**: 같은 테이블 SQL끼리 모아 정렬 → 연속 구문이 배치로 묶이게 해준다.
