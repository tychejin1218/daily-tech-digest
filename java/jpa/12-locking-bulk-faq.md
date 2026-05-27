### Q1. `@Version`은 어떻게 동시 수정을 감지하나요?

UPDATE 시 WHERE 절에 읽어둔 version 값을 함께 넣고, 성공하면 version을 +1 한다. 다른 트랜잭션이 먼저 커밋했다면 version이 이미 바뀌어 `WHERE ... AND version=1`이 0행 매칭되고, Hibernate가 이를 감지해 `OptimisticLockException`을 던진다. DB 락을 잡지 않아 가볍다.

```java
@Version
private Long version;   // UPDATE ... WHERE id=? AND version=? → 0행이면 충돌
```

> 💡 **정리**: version을 WHERE에 넣어 "내가 읽은 뒤 아무도 안 바꿨나"를 검증한다.

---

### Q2. 낙관적 락과 비관적 락은 언제 각각 쓰나요?

**낙관적 락(@Version)**은 충돌이 드문 경우에 적합하다. 락을 안 걸어 빠르고, 충돌 시 예외로 재시도/알림을 한다. **비관적 락(`SELECT ... FOR UPDATE`)**은 충돌이 잦거나 반드시 순서를 보장해야 할 때(재고 차감 등) DB 행 락을 직접 잡는다. 대기·데드락 위험이 있으니 꼭 필요할 때만 쓴다.

```java
@Lock(LockModeType.PESSIMISTIC_WRITE)   // 비관적 락
@Query("SELECT s FROM Stock s WHERE s.id = :id")
Stock findByIdForUpdate(@Param("id") Long id);
```

> 💡 **정리**: 충돌 드물면 낙관적(@Version), 잦거나 순서 보장 필수면 비관적 락.

---

### Q3. `@Modifying` 벌크 연산을 쓸 때 가장 조심할 점은?

벌크 연산은 **영속성 컨텍스트를 거치지 않고 DB에 바로 SQL을 날린다**. 그래서 같은 트랜잭션에서 이미 1차 캐시에 올라온 Entity가 있으면, DB는 바뀌었는데 캐시 속 Entity는 옛날 값 그대로라 둘이 어긋난다. 이게 벌크 연산의 대표 함정이다.

```java
@Modifying
@Query("UPDATE DbankWorksheet w SET w.isDeleted = true WHERE w.id IN :ids")
int bulkSoftDelete(@Param("ids") List<Long> ids);
```

> 💡 **정리**: 벌크 연산은 영속성 컨텍스트를 우회해 DB에 직접 실행된다 — 캐시와 어긋날 수 있다.

---

### Q4. `clearAutomatically = true`는 왜 붙이나요?

벌크 연산 후 1차 캐시에 남은 옛 Entity와 DB 상태가 어긋나는 걸 막기 위해서다. 이 옵션을 켜면 벌크 실행 직후 영속성 컨텍스트를 자동으로 `clear()` 해, 이후 조회가 DB에서 최신 값을 새로 읽어오게 한다. 벌크 연산엔 거의 필수로 붙인다.

```java
@Modifying(clearAutomatically = true)   // 실행 후 컨텍스트 초기화
@Query("UPDATE DbankWorksheet w SET w.isDeleted = true WHERE w.id IN :ids")
int bulkSoftDelete(@Param("ids") List<Long> ids);
```

> 💡 **정리**: clearAutomatically=true로 벌크 후 캐시를 비워 DB와의 불일치를 막는다.

---

### Q5. 벌크 UPDATE 직후 같은 트랜잭션에서 조회했더니 옛날 값이 나와요. 왜죠?

벌크로 DB는 바뀌었지만, 같은 트랜잭션의 1차 캐시에 이미 그 Entity가 있으면 **조회가 캐시의 옛 값을 돌려주기** 때문이다(특히 findById). `clearAutomatically = true`로 캐시를 비우거나, 직접 `em.clear()` 후 다시 조회하면 최신 값을 읽는다.

> 💡 **정리**: 벌크 후 캐시에 옛 Entity가 남아 그렇다. clear 후 재조회하면 최신값이 나온다.
