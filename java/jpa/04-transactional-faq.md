### Q1. `@Transactional(readOnly = true)`는 구체적으로 뭘 해주나요?

두 가지다. ①Hibernate의 flush 모드를 MANUAL로 바꿔 Dirty Checking/flush를 생략하므로 스냅샷 비교 비용이 줄고, ②Read/Write DB가 분리된 환경에서 보통 **Read 복제본으로 라우팅**되어 부하를 분산한다. 조회 전용 메서드엔 습관적으로 붙이는 게 좋다.

```java
@Transactional(readOnly = true)
public WorksheetDetailDto.Response get(Long id) { ... }
```

> 💡 **정리**: readOnly는 flush 생략(성능)+Read DB 라우팅(부하 분산) 두 효과를 준다.

---

### Q2. 같은 클래스 안에서 메서드를 호출했더니 @Transactional이 안 먹어요. 왜죠?

Spring의 `@Transactional`은 **프록시 기반**이라, 외부에서 빈을 거쳐 호출될 때만 트랜잭션 부가 로직이 끼어든다. 같은 클래스 안에서 `this.method()`로 부르면 프록시를 거치지 않아(self-invocation) 어노테이션이 무시된다. 별도 빈으로 분리하거나 자기 자신을 프록시로 주입받아 호출해야 한다.

```java
public void outer() {
    this.inner();   // ❌ 프록시 안 거침 → @Transactional 무시
}

@Transactional
public void inner() { ... }
```

> 💡 **정리**: 내부 호출(self-invocation)은 프록시를 안 거쳐 트랜잭션이 안 걸린다. 빈을 분리하라.

---

### Q3. 예외가 났는데 롤백이 안 됐어요. 정상인가요?

기본 동작상 `@Transactional`은 **RuntimeException(unchecked)과 Error**에서만 롤백하고, `checked exception`(예: `IOException`)에서는 롤백하지 않는다. checked 예외에도 롤백하려면 `rollbackFor`를 지정해야 한다.

```java
@Transactional(rollbackFor = Exception.class)
public void process() throws IOException { ... }
```

> 💡 **정리**: 기본 롤백은 unchecked 예외만. checked까지 원하면 rollbackFor 지정.

---

### Q4. readOnly=true 메서드에서 Entity를 수정하면 어떻게 되나요?

flush 모드가 MANUAL이라 Dirty Checking 결과가 DB로 나가지 않는다. 즉 변경이 조용히 무시된다(DB 구성에 따라 Read 커넥션이라 예외가 날 수도 있다). 그래서 readOnly는 "조회 전용"을 코드로 강제하는 안전장치 역할도 한다.

> 💡 **정리**: readOnly에서의 변경은 flush되지 않아 무시된다 — 조회 전용을 보장하는 셈.

---

### Q5. 트랜잭션 전파(propagation)는 언제 신경 써야 하나요?

대부분 기본값 `REQUIRED`(기존 트랜잭션 있으면 참여, 없으면 새로 시작)면 충분하다. "바깥 작업이 롤백돼도 이 로그/이력은 남겨야 한다" 같은 경우엔 `REQUIRES_NEW`로 별도 트랜잭션을 띄운다. 단, REQUIRES_NEW는 커넥션을 추가로 점유하므로 남발하면 커넥션 풀이 마른다.

```java
@Transactional(propagation = Propagation.REQUIRES_NEW)
public void writeAuditLog(...) { ... }   // 바깥이 롤백돼도 독립 커밋
```

> 💡 **정리**: 기본 REQUIRED로 충분. 독립 커밋이 필요한 이력성 작업에만 REQUIRES_NEW.
