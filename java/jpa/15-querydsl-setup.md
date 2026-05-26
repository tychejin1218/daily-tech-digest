### 1. QueryDSL Gradle 설정 — Q클래스 자동 생성 파이프라인

QueryDSL은 Entity로부터 **Q클래스(QDbankWorksheet 등)** 를 컴파일 시점에 생성해 타입 안전성을 제공한다. Gradle의 `annotationProcessor`로 `jakarta.persistence.Entity`를 스캔해 Q클래스를 만들며, 빌드 결과물(`build/generated/sources/annotationProcessor`)을 소스 경로로 등록해야 IDE 자동완성이 동작한다.

```gradle
// build.gradle (Spring Boot 3.x + Jakarta)
dependencies {
    implementation 'com.querydsl:querydsl-jpa:5.1.0:jakarta'

    annotationProcessor 'com.querydsl:querydsl-apt:5.1.0:jakarta'
    annotationProcessor 'jakarta.annotation:jakarta.annotation-api'
    annotationProcessor 'jakarta.persistence:jakarta.persistence-api'
}

// Q클래스 생성 경로 등록 (IDE에서 import 가능하게 함)
sourceSets {
    main {
        java {
            srcDirs += "$buildDir/generated/sources/annotationProcessor/java/main"
        }
    }
}

// clean 시 Q클래스 폴더 같이 삭제
clean {
    delete file("$buildDir/generated/sources/annotationProcessor")
}
```

```
Entity → Q클래스 생성 흐름:

DbankWorksheet.java (소스)
        │
        │ @Entity 스캔
        ▼
querydsl-apt (annotation processor)
        │
        ▼
QDbankWorksheet.java (build/generated/.../QDbankWorksheet.java)
        │
        │ public static final QDbankWorksheet dbankWorksheet = ...
        │ public final NumberPath<Long> id = createNumber("id", Long.class);
        │ public final StringPath worksheetName = createString("worksheetName");
        ▼
JPAQueryFactory에서 타입 안전하게 사용
```

> 💡 **왜 중요한가**: Q클래스가 없거나 오래된 상태로 코드를 작성하면 IDE 자동완성이 안 되거나 빌드만 깨지므로, Entity 필드를 추가/변경한 후에는 `./gradlew compileJava`로 Q클래스를 재생성하는 습관이 필요하다.

---

### 2. JPAQueryFactory 설정 — @Configuration으로 Bean 등록

`JPAQueryFactory`는 QueryDSL 쿼리의 진입점으로, `EntityManager`를 주입받아 동작한다. Repository마다 `new JPAQueryFactory(em)`를 만들지 말고 **@Configuration에서 Bean으로 등록**해 어디서든 주입받을 수 있게 해야 트랜잭션 컨텍스트가 안전하게 연결된다.

```java
// QuerydslConfig.java — 전역 JPAQueryFactory Bean 등록
@Configuration
public class QuerydslConfig {

    @PersistenceContext
    private EntityManager em;

    @Bean
    public JPAQueryFactory jpaQueryFactory() {
        return new JPAQueryFactory(em);
    }
}
```

```java
// 사용 — Repository에서 주입만 받으면 됨
@Repository
@RequiredArgsConstructor
public class WorksheetQueryRepository {

    private final JPAQueryFactory queryFactory;

    public List<DbankWorksheet> findActiveWorksheets() {
        QDbankWorksheet w = QDbankWorksheet.dbankWorksheet;
        return queryFactory
            .selectFrom(w)
            .where(w.isDeleted.eq(false))
            .fetch();
    }
}
```

```
EntityManager 주입 방식 비교:

@PersistenceContext EntityManager em;
  → JPA 표준, 트랜잭션마다 프록시가 실제 EM을 찾아줌 (스레드 안전)

@Autowired EntityManager em;
  → Spring 4.x+ 동작하지만 명시적이지 않음

new JPAQueryFactory(em) 직접 생성 (Repository마다)
  → 트랜잭션 전파/상태 디버깅이 어려워짐 (지양)
```

> 💡 **왜 중요한가**: `JPAQueryFactory`는 내부적으로 `EntityManager`의 트랜잭션 범위 내에서 동작하므로, Bean으로 등록해 `@PersistenceContext` 프록시를 통해 주입받아야 멀티스레드 환경에서 트랜잭션 컨텍스트가 안전하게 전파된다.
