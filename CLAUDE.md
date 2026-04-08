# Daily Tech Digest

매일 08:40 자동 실행되는 기술 학습 다이제스트. `generate.sh`가 Claude CLI를 호출해 4개 카테고리 파일을 생성하고 GitHub에 자동 push한다.

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
├── news/        # IT 뉴스 (3개 항목)
├── java/        # Java 팁 (2개 항목)
├── springboot/  # Spring Boot 팁 (2개 항목)
├── database/    # Database 팁 (2개 항목)
└── generate.sh  # 생성 스크립트
```

파일명: `YYYY-MM-DD.md` (같은 날 재실행 시 `YYYY-MM-DD(2).md`, `(3).md` ...)

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

새 파일 작성 시 해당 카테고리 디렉토리의 최근 파일을 읽고 `### 제목` 목록을 확인한 뒤 겹치는 주제를 피할 것. `generate.sh`는 이를 자동으로 처리하지만 수동 작성 시에도 동일하게 적용.

## 자동화

- **스케줄**: 매일 08:40 (launchd: `~/Library/LaunchAgents/com.daekyo.daily-tech-digest.plist`)
- **로그**: `generate.log`
- **generate.sh 동작**: 파일 생성 → `git add .` → `git commit` → `git push origin main`
