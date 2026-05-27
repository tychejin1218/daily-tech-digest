### Q1. Q클래스(QDbankWorksheet)는 뭐고 어떻게 만들어지나요?

Entity 메타정보를 담은 **자동 생성 클래스**로, 필드를 타입 안전한 경로(`Path`)로 노출한다. 빌드 시 `querydsl-apt` 애너테이션 프로세서가 `@Entity`를 스캔해 `build/generated/...`에 생성한다. 그 생성 경로를 sourceSet에 등록해야 IDE가 import하고 자동완성한다.

```java
QDbankWorksheet w = QDbankWorksheet.dbankWorksheet;
w.worksheetName.contains(keyword);   // 컴파일 시 타입 검증되는 경로
```

> 💡 **정리**: Q클래스는 컴파일 때 apt가 Entity로부터 만드는 타입 안전 경로 클래스다.

---

### Q2. Entity에 필드를 추가했는데 QueryDSL 자동완성에 안 나와요. 왜죠?

Q클래스는 빌드 시점에 생성된 스냅샷이라, Entity를 바꾸면 **재생성**해야 반영된다. `./gradlew compileJava`(또는 빌드)로 Q클래스를 다시 만들면 새 필드가 나타난다. 빌드가 깨질 때는 `clean` 후 다시 컴파일해 옛 Q클래스를 지운다.

```bash
./gradlew clean compileJava   # Q클래스 재생성
```

> 💡 **정리**: Q클래스는 빌드 산출물 — Entity 변경 후 재컴파일해야 최신 필드가 반영된다.

---

### Q3. `JPAQueryFactory`를 Repository마다 `new`로 만들면 안 되나요?

권장하지 않는다. `@Configuration`에서 Bean으로 한 번 등록하고 주입받아야, `@PersistenceContext`가 넣어준 **트랜잭션 범위의 EntityManager 프록시**를 통해 동작해 스레드/트랜잭션 컨텍스트가 안전하게 연결된다. Repository마다 직접 생성하면 트랜잭션 전파·디버깅이 까다로워진다.

```java
@Bean
public JPAQueryFactory jpaQueryFactory(EntityManager em) {
    return new JPAQueryFactory(em);   // 한 번만 등록, 어디서든 주입
}
```

> 💡 **정리**: JPAQueryFactory는 Bean으로 등록해 EM 프록시로 동작시킨다 — Repository마다 new 금지.

---

### Q4. `@PersistenceContext`와 `@Autowired EntityManager`는 뭐가 다른가요?

`@PersistenceContext`는 JPA 표준 방식으로, 실제 EntityManager가 아니라 **현재 트랜잭션의 EM을 찾아주는 프록시**를 주입한다. 그래서 멀티스레드에서 각 요청이 자기 트랜잭션의 EM을 안전하게 쓴다. `@Autowired`로도 동작은 하지만 의도가 덜 명확하므로 표준인 `@PersistenceContext`를 쓰는 게 좋다.

> 💡 **정리**: @PersistenceContext는 트랜잭션별 EM을 찾아주는 프록시를 주입 — 표준이자 안전.

---

### Q5. Spring Boot 3에서 QueryDSL 의존성이 왜 `:jakarta` 분류자가 붙나요?

Spring Boot 3 / Hibernate 6부터 패키지가 `javax.persistence`에서 **`jakarta.persistence`**로 바뀌었기 때문이다. QueryDSL도 이에 맞춘 `:jakarta` 분류자 아티팩트(`querydsl-jpa:5.x:jakarta`, `querydsl-apt:5.x:jakarta`)를 써야 한다. 분류자를 빠뜨리면 javax용이 받아져 컴파일/런타임 에러가 난다.

```gradle
implementation 'com.querydsl:querydsl-jpa:5.1.0:jakarta'
annotationProcessor 'com.querydsl:querydsl-apt:5.1.0:jakarta'
```

> 💡 **정리**: Boot 3는 jakarta 네임스페이스 → QueryDSL도 :jakarta 분류자를 꼭 붙인다.
