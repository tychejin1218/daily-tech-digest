# Daily Tech Digest

매일 08:40 자동 실행되고 13:30에 누락분을 채우는 기술 학습 다이제스트. `generate.sh`가 Claude CLI를 호출해 5개 카테고리 파일을 생성하고 GitHub에 자동 push한다.

## 금지 규칙

- **MD 파일 최상단에 `# 제목` 머리말 절대 금지** — `###`으로 바로 시작
- 같은 날 또는 최근에 다룬 주제 반복 금지 (카테고리별 최근 파일 확인 필수)
- 마지막 항목 뒤에 `---` 금지

## 명령어

```bash
bash generate.sh          # 수동 실행 (생성 → git add . → commit → push 자동 수행)
launchctl start com.daekyo.daily-tech-digest  # launchd 즉시 실행
cat generate.log          # 실행 로그 확인
```

## 디렉토리 구조

```
daily-tech-digest/
├── news/YYYY-MM/        # IT 뉴스 (3개 항목) — 월별 폴더
├── java/YYYY-MM/        # Java 팁 (2개 항목) — 월별 폴더
│   └── jpa/             # JPA 큐레이션 가이드(번호 파일) — 일일분 아님, 중복 방지 대상 제외
├── springboot/YYYY-MM/  # Spring Boot 팁 (2개 항목) — 월별 폴더
├── database/YYYY-MM/    # Database 팁 (2개 항목) — 월별 폴더
├── architecture/YYYY-MM/ # 아키텍처 (1개 항목, AI 시대 시스템 설계) — 월별 폴더
└── generate.sh          # 생성 스크립트
```

파일 경로: `카테고리/YYYY-MM/YYYY-MM-DD.md` (일일분은 월 단위 폴더로 관리). 같은 날 재실행 시 `YYYY-MM-DD(2).md`, `(3).md` ...

## MD 파일 양식

```markdown
### 제목

설명 (2-3문장). 코드가 있으면 코드 블록 포함.

> 💡 **왜 중요한가**: 한 문장 요약

---

### 다음 항목 제목
```

항목 사이는 `---`로 구분, 마지막 항목 뒤에는 `---` 없음.

## 중복 방지

새 파일 작성 시 해당 카테고리의 월 폴더(`YYYY-MM`) 최근 파일을 읽고 `### 제목` 목록을 확인한 뒤 겹치는 주제를 피할 것. `generate.sh`는 월 폴더를 가로질러 최신 10개를 자동 확인하며(`java/jpa/` 같은 비날짜 폴더는 제외), 월이 바뀌어도 직전 달 주제까지 참조한다. 수동 작성 시에도 동일하게 적용.

## 자동화

- **스케줄**: 매일 08:40 (기본 실행) + 13:30 (catch-up — 08:40에 누락된 카테고리만 채움). launchd: `~/Library/LaunchAgents/com.daekyo.daily-tech-digest.plist`
- **로그**: `generate.log`
- **generate.sh 동작**: 5개 파일 모두 존재하면 즉시 종료(catch-up guard). 누락분만 생성 → `git add .` → `git commit` → `git push origin main`. 각 카테고리 블록도 `[ ! -s "$DIR/${DATE}.md" ]` 가드로 보호되어 이미 완료된 카테고리는 건너뜀
