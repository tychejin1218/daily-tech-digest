# Daily Tech Digest

매일 08:40 자동 실행되는 기술 학습 다이제스트. launchd로 스케줄링되며 `generate.sh`가 Claude CLI를 호출해 4개 카테고리 파일을 생성하고 GitHub에 push한다.

## 디렉토리 구조

```
daily-tech-digest/
├── news/        # IT 뉴스 (3개)
├── java/        # Java 팁 (2개)
├── springboot/  # Spring Boot 팁 (2개)
├── database/    # Database 팁 (2개)
└── generate.sh  # 생성 스크립트
```

파일명: `YYYY-MM-DD.md` (같은 날 재실행 시 `YYYY-MM-DD(2).md`, `(3).md` ...)

## MD 파일 양식

```markdown
### 제목

설명 (2-3문장). 코드가 있으면 코드 블록 포함.

```코드 예시 (선택)```

> 💡 **왜 중요한가**: 한 문장 요약

---

### 다음 항목 제목
...
```

**규칙:**
- 파일 최상단에 `# 제목` 머리말 없음 — `###`으로 바로 시작
- 항목 사이는 `---`로 구분
- 마지막 항목 뒤에는 `---` 없음

## 중복 방지

`generate.sh`는 각 카테고리 최근 10개 파일에서 `### 제목`을 추출해 프롬프트에 포함시킨다. 새 파일 작성 시에도 같은 원칙 — 해당 카테고리의 최근 파일을 확인하고 겹치는 주제는 피할 것.

## 자동화

- **스케줄**: 매일 08:40 (launchd: `~/Library/LaunchAgents/com.daekyo.daily-tech-digest.plist`)
- **로그**: `generate.log`
- **수동 실행**: `bash generate.sh`
