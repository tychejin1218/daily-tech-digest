### Q1. 새로 만든 Entity는 save()가 필요한데, 조회한 Entity는 왜 save() 없이 수정되나요?

새로 만든 객체는 **비영속(transient)** 상태라 영속성 컨텍스트가 모르는 객체다. 그래서 `save()`로 등록해야 INSERT가 된다. 반면 `findById`로 조회한 객체는 이미 **영속(managed)** 상태라 컨텍스트가 추적 중이고, 필드만 바꿔도 커밋 시 Dirty Checking으로 자동 UPDATE된다.

```java
DbankWorksheet n = request.toEntity(...);                  // 비영속 → save() 필요
worksheetRepository.save(n);

DbankWorksheet m = repository.findById(1L).orElseThrow();  // 영속
m.softDelete(userId);                                      // save() 불필요, 자동 UPDATE
```

> 💡 **정리**: "새로 만든 것만 save(), 조회한 것은 필드만 변경" — 상태 차이에서 나오는 규칙이다.

---

### Q2. "트랜잭션 끝나고 LAZY 필드 건드렸더니 터졌다"는 왜 그런가요?

트랜잭션이 끝나면 Entity는 **준영속(detached)** 상태가 되어 영속성 컨텍스트의 관리를 벗어난다. 이때 아직 초기화되지 않은 LAZY 연관을 건드리면 프록시를 채울 영속성 컨텍스트가 없어 `LazyInitializationException`이 난다. 그래서 필요한 데이터는 트랜잭션 안에서 미리 초기화하거나 DTO로 변환해 나와야 한다. (자세한 메커니즘은 10번 FAQ)

> 💡 **정리**: 준영속 상태에서는 LAZY 로딩이 불가능하니, 트랜잭션 안에서 필요한 것을 다 꺼낸다.

---

### Q3. findById를 두 번 해도 SELECT가 한 번만 나가던데, QueryDSL도 그런가요?

아니다. 1차 캐시는 `findById`/`em.find` 같은 **PK 기반 조회**에서만 동작한다. 두 번째 `findById(1L)`은 DB를 안 치고 캐시에서 돌려준다. 하지만 JPQL/QueryDSL은 항상 DB에 SELECT를 날린 뒤, 결과의 PK가 캐시에 있으면 그 객체로 대체하는 방식이라 SELECT 자체는 매번 실행된다.

```java
worksheetRepository.findById(1L);  // SELECT 1회
worksheetRepository.findById(1L);  // 캐시 → SELECT 없음
queryRepository.selectById(1L);    // QueryDSL → 매번 SELECT
```

> 💡 **정리**: 1차 캐시는 PK 조회 전용. QueryDSL/JPQL은 매번 쿼리가 나간다.

---

### Q4. 같은 ID로 두 번 조회하면 `==` 비교가 true인 이유는?

같은 트랜잭션(=같은 영속성 컨텍스트) 안에서는 같은 PK에 대해 **동일성(identity)**을 보장하기 때문이다. 두 번째 조회가 1차 캐시의 같은 인스턴스를 돌려주므로 `equals`가 아니라 `==`까지 true가 된다. 단 트랜잭션이 다르면 다른 인스턴스이므로 이 보장은 깨진다.

```java
@Transactional
void t() {
    var a = repo.findById(1L).get();
    var b = repo.findById(1L).get();
    assert a == b;   // true (동일성 보장)
}
```

> 💡 **정리**: 동일성 보장은 "한 트랜잭션 + 같은 PK" 안에서만 성립한다.

---

### Q5. 준영속 객체를 다시 영속 상태로 만들려면 merge()를 쓰면 되나요?

`merge()`는 준영속 객체의 값을 복사한 **새 영속 객체를 반환**한다. 즉 원본은 여전히 준영속이고, 반환값을 써야 한다. 다만 실무에서는 merge보다, 트랜잭션 안에서 `findById`로 다시 조회한 뒤 변경값을 세팅하는 방식이 어떤 필드가 바뀌는지 명확해 더 안전하다.

```java
DbankWorksheet managed = em.merge(detached); // managed가 영속, detached는 그대로

// 권장: 조회 후 변경
DbankWorksheet ws = repo.findById(id).get();
ws.rename(req.getName());
```

> 💡 **정리**: merge는 "병합한 새 객체"를 돌려준다. 가급적 재조회 후 변경 패턴을 쓴다.
