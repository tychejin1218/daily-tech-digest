### Q1. N+1은 왜 개발할 땐 멀쩡하다가 운영에서 터지나요?

쿼리 수가 **데이터 건수에 비례**하기 때문이다. 개발 DB엔 부모가 몇 건뿐이라 1+2, 1+3 수준이라 체감이 없지만, 운영에서 부모가 수천 건이면 1+수천 번의 SELECT가 나간다. 그래서 개발 단계에서 실행 SQL 로그(p6spy 등)로 쿼리 수를 직접 확인하는 습관이 중요하다.

> 💡 **정리**: N+1은 데이터가 쌓여야 드러난다. 개발 때 SQL 로그로 쿼리 수를 미리 확인하라.

---

### Q2. N+1 해결에 fetch join과 default_batch_fetch_size 중 뭘 써야 하나요?

역할이 다르다. **xToOne**(ManyToOne/OneToOne) 관계나 페이징 없는 단건 조회는 `fetch join`이 깔끔하다. **xToMany**(컬렉션) 관계나 페이징이 섞이면 `default_batch_fetch_size`가 안전하다. 실무에선 batch_fetch_size를 전역으로 깔아두고, 특정 조회만 fetch join으로 최적화하는 조합이 많다.

```yaml
spring.jpa.properties.hibernate.default_batch_fetch_size: 100  # 전역 기본
```

> 💡 **정리**: xToOne·단건은 fetch join, 컬렉션·페이징은 batch_fetch_size. 둘을 병행한다.

---

### Q3. 컬렉션을 fetch join하면서 페이징하면 왜 위험한가요?

컬렉션 fetch join은 부모-자식이 조인된 **펼쳐진 결과**라 행 수가 부모 수와 다르다. 여기에 `limit`을 걸면 DB에서 자를 수 없어 Hibernate가 **전체를 메모리로 읽은 뒤 페이징**한다(`firstResult/maxResults specified with collection fetch` 경고 + OutOfMemory 위험). 그래서 컬렉션 페이징은 fetch join 대신 batch_fetch_size로 푸는 게 안전하다.

> 💡 **정리**: 컬렉션 fetch join + 페이징 = 메모리 페이징(위험). 페이징은 batch_fetch_size로.

---

### Q4. fetch join으로 컬렉션을 두 개 이상 동시에 가져오면 어떻게 되나요?

`MultipleBagFetchException`이 난다. List(=bag) 컬렉션을 둘 이상 동시에 fetch join하면 카테시안 곱으로 데이터가 폭증해 Hibernate가 막는다. 하나만 fetch join하고 나머지는 batch_fetch_size로 가져오거나, 컬렉션 타입을 `Set`으로 바꾸는 식으로 해결한다.

> 💡 **정리**: 컬렉션 fetch join은 하나만. 나머지는 batch_fetch_size로 분산한다.

---

### Q5. `@EntityGraph`는 fetch join과 뭐가 다른가요?

효과는 비슷하다(연관을 함께 조회). 차이는 작성 방식이다. fetch join은 JPQL 문자열에 직접 쓰고, `@EntityGraph`는 메서드에 어노테이션으로 "이 연관을 같이 로딩하라"고 선언해 **기본 파생 쿼리에도 얹을 수 있다**. 단순히 "이 연관 같이 로딩" 정도면 EntityGraph가 깔끔하고, 복잡한 조인 조건이 필요하면 fetch join이 낫다.

```java
@EntityGraph(attributePaths = {"questions"})
List<DbankWorksheet> findAll();   // findAll에 연관 로딩을 얹음
```

> 💡 **정리**: 둘 다 함께 조회. 선언적으로 얹으려면 @EntityGraph, 조인 조건이 복잡하면 fetch join.
