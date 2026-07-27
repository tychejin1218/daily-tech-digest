#!/bin/bash
# 손상된 다이제스트 MD 파일과 완전 누락된 날짜를 스캔해서 백필한다.
# 사용법:
#   bash regenerate-broken.sh --dry-run   # 감지 결과만 출력
#   bash regenerate-broken.sh             # 실제로 재생성 + git push

set -uo pipefail

BASE_DIR="/Users/daekyo/personal/daily-tech-digest"
CATS="news java springboot database architecture"
TODAY=$(date +%Y-%m-%d)

DRY_RUN=0
if [ "${1:-}" = "--dry-run" ]; then
  DRY_RUN=1
fi

# 손상 판정: generate.sh의 run_claude 검증과 동일한 규칙
# 반환 0=broken, 1=ok/missing
is_broken() {
  local f="$1"
  [ ! -f "$f" ] && return 1
  [ ! -s "$f" ] && return 0   # 0바이트
  local first_line size
  first_line=$(head -c 80 "$f")
  case "$first_line" in
    "API Error"*|"Failed to authenticate"*|"Request timed out"*|"Error:"*|"Warning:"*)
      return 0 ;;
  esac
  size=$(wc -c < "$f" | tr -d ' ')
  # 500바이트 미만이고 ### 헤딩이 없으면 대화형/에러 응답으로 간주
  if [ "$size" -lt 500 ] && ! grep -q '^###' "$f" 2>/dev/null; then
    return 0
  fi
  return 1
}

echo "=========================================="
echo " Phase 1: 손상 파일 스캔"
echo "=========================================="
broken_files=""
affected_dates=""
for cat in $CATS; do
  for f in "$BASE_DIR/$cat"/[0-9][0-9][0-9][0-9]-[0-9][0-9]/[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9].md; do
    [ -e "$f" ] || continue
    if is_broken "$f"; then
      date_part=$(basename "$f" .md)
      size=$(wc -c < "$f" | tr -d ' ')
      first_line=$(head -c 100 "$f" | LC_ALL=C tr '\n' ' ')
      echo "  [손상] $cat/$date_part (${size}B): ${first_line:0:80}..."
      broken_files="${broken_files}${f}"$'\n'
      affected_dates="${affected_dates}${date_part}"$'\n'
    fi
  done
done
[ -z "$broken_files" ] && echo "  손상 파일 없음"

echo ""
echo "=========================================="
echo " Phase 2: 완전 누락 날짜 감지 (5개 카테고리 모두 없는 날)"
echo "=========================================="
# 최초 날짜 파악: 모든 카테고리 중 가장 이른 파일
first_date=""
for cat in $CATS; do
  cand=$(ls -1 "$BASE_DIR/$cat"/[0-9][0-9][0-9][0-9]-[0-9][0-9]/[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9].md 2>/dev/null | head -1 | xargs -I{} basename {} .md)
  if [ -n "$cand" ]; then
    if [ -z "$first_date" ] || [ "$cand" \< "$first_date" ]; then
      first_date="$cand"
    fi
  fi
done

if [ -z "$first_date" ]; then
  echo "  최초 날짜 파악 실패 — 스킵"
else
  echo "  범위: $first_date ~ $TODAY (오늘 제외)"
  current="$first_date"
  missing_dates=""
  while [[ "$current" < "$TODAY" ]]; do
    missing_count=0
    for cat in $CATS; do
      m="${current:0:7}"
      f="$BASE_DIR/$cat/$m/${current}.md"
      [ ! -f "$f" ] && missing_count=$((missing_count + 1))
    done
    if [ "$missing_count" -eq 5 ]; then
      echo "  [누락] $current"
      missing_dates="${missing_dates}${current}"$'\n'
      affected_dates="${affected_dates}${current}"$'\n'
    fi
    current=$(date -j -f "%Y-%m-%d" -v+1d "$current" +"%Y-%m-%d")
  done
  [ -z "$missing_dates" ] && echo "  완전 누락 날짜 없음"
fi

echo ""
echo "=========================================="
echo " 요약"
echo "=========================================="
uniq_dates=$(printf '%s' "$affected_dates" | grep -v '^$' | sort -u)
if [ -z "$uniq_dates" ]; then
  echo "  재생성할 것 없음 — 종료"
  exit 0
fi
count=$(printf '%s\n' "$uniq_dates" | wc -l | tr -d ' ')
echo "  재생성 대상 날짜 (${count}일):"
printf '%s\n' "$uniq_dates" | sed 's/^/    /'

if [ "$DRY_RUN" -eq 1 ]; then
  echo ""
  echo "  DRY_RUN — 재생성 스킵. 실제 실행: bash regenerate-broken.sh"
  exit 0
fi

echo ""
echo "=========================================="
echo " Phase 3: 손상 파일 삭제"
echo "=========================================="
if [ -n "$broken_files" ]; then
  printf '%s' "$broken_files" | grep -v '^$' | while IFS= read -r f; do
    rm -f "$f"
    echo "  삭제: $f"
  done
fi

echo ""
echo "=========================================="
echo " Phase 4: 재생성 (DATE override + SKIP_GIT=1)"
echo "=========================================="
printf '%s\n' "$uniq_dates" | while IFS= read -r d; do
  [ -z "$d" ] && continue
  echo ""
  echo "▶▶▶ $d"
  DATE="$d" SKIP_GIT=1 bash "$BASE_DIR/generate.sh" || {
    rc=$?
    echo "  ⚠ $d generate.sh 리턴 코드 $rc — 다음 날짜로 진행"
  }
done

echo ""
echo "=========================================="
echo " Phase 5: 재검증 & git commit/push"
echo "=========================================="
# 재검증: 방금 재생성한 날짜의 파일들이 여전히 손상인지 확인
still_broken=""
printf '%s\n' "$uniq_dates" | while IFS= read -r d; do
  [ -z "$d" ] && continue
  m="${d:0:7}"
  for cat in $CATS; do
    f="$BASE_DIR/$cat/$m/${d}.md"
    if [ ! -f "$f" ]; then
      echo "  ⚠ 여전히 없음: $cat/$m/${d}.md"
    elif is_broken "$f"; then
      echo "  ⚠ 여전히 손상: $cat/$m/${d}.md"
    fi
  done
done

cd "$BASE_DIR"
if [ -n "$(git status --porcelain)" ]; then
  git add .
  git commit -m "Restore broken/missing daily digests ($count days)"
  git push origin main
  echo "  ✓ push 완료"
else
  echo "  변경 없음 — 커밋 스킵 (아마도 재생성이 모두 실패했거나 파일 상태가 변경되지 않음)"
fi

echo ""
echo "완료."
