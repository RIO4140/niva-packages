#!/bin/sh
# تشغيل اختبارات حزم: كل برنامج اختبار .نيفا يعمل في الوضعين
# (المترجم الافتراضي والمفسر التشخيصي) في مجلد مؤقت جديد تماما،
# والناجح هو الذي يطبع «ناجح». مجلد جديد لكل تشغيل لأن اختبار
# المخزن يبدأ من مخزن فارغ في الوضعين معا.
# لا إطار اختبار في لغة Niva بعد — فالسكربت يحكم.
# واختبارات النشر تعمل ضد خادم محاكٍ لجيت هاب على
# 127.0.0.1:39401 (tests/mock-github.js) — بلا شبكة
# حقيقية — وتُشغَّل وحدها برايتي الشبكة المحلية.
# (أسماء متغيرات الشل لاتينية — معرّفات داخلية لا تظهر للمستخدم؛ وكل النصوص عربية.)
set -u

if command -v نيفا >/dev/null 2>&1; then
  NIVA="نيفا"
elif [ -x "$HOME/.local/bin/نيفا" ]; then
  NIVA="$HOME/.local/bin/نيفا"
else
  echo "ثنائي نيفا غير موجود — شغّل أولا: sh tools/تمهيد.sh"
  exit 1
fi

cd "$(dirname "$0")/.."
TMPROOT=".test-tmp"
rm -rf "$TMPROOT"
mkdir -p "$TMPROOT"
MOCK_PID=""
trap 'rm -rf "$TMPROOT"; if [ -n "$MOCK_PID" ]; then kill "$MOCK_PID" 2>/dev/null; fi' EXIT INT TERM
passed=0
failed=0

if [ -f "tests/mock-github.js" ] && command -v node >/dev/null 2>&1; then
  # قد يبقى محاكٍ قديم عالقا من تشغيل سابق على المنفذ نفسه —
  # أقتله أولا وإلا اختبرت التشغيلة ضد خادم قديم.
  fuser -k 39401/tcp 2>/dev/null || true
  sleep 1
  node tests/mock-github.js > "$TMPROOT/mock.log" 2>&1 &
  MOCK_PID=$!
  ready=0
  i=0
  while [ "$i" -lt 10 ]; do
    if curl -s --max-time 2 "http://127.0.0.1:39401/__صحة" >/dev/null 2>&1; then
      ready=1
      break
    fi
    sleep 1
    i=$((i + 1))
  done
  if [ "$ready" -eq 0 ]; then
    echo "تحذير: خادم جيت هاب المحاكي لم يبدأ — اختبارات النشر ستفشل"
  fi
fi

run_one() {
  test_file="$1"
  mode_flag="$2"
  mode_name="$3"
  expect="$4"
  test_name="$(basename "$test_file" .نيفا)"
  if [ -n "$mode_flag" ]; then
    dir="$TMPROOT/${test_name}-مفسر"
  else
    dir="$TMPROOT/${test_name}-مترجم"
  fi
  mkdir -p "$dir"
  cp src/*.نيفا "$dir/"
  cp -r tests/fixtures/* "$dir/" 2>/dev/null || true
  cp "$test_file" "$dir/"
  base="$(basename "$test_file")"
  case "$test_file" in
    *نشر*)
      netflags="--اسمح-بالشبكة --مضيف-محلي 127.0.0.1"
      ;;
    *)
      netflags=""
      ;;
  esac
  if [ -z "$mode_flag" ]; then
    # shellcheck disable=SC2086
    out="$($NIVA $netflags "$dir/$base" 2>/dev/null)"
  else
    # shellcheck disable=SC2086
    out="$($NIVA "$mode_flag" $netflags "$dir/$base" 2>/dev/null)"
  fi
  if printf '%s\n' "$out" | grep -qx "$expect"; then
    echo "ناجح: $test_file ($mode_name)"
    passed=$((passed + 1))
  else
    echo "فاشل: $test_file ($mode_name)"
    echo "--- مخرجات $test_file ($mode_name) ---"
    printf '%s\n' "$out"
    echo "--- نهاية المخرجات ---"
    failed=$((failed + 1))
  fi
}

for test in tests/unit/*.نيفا; do
  [ -e "$test" ] || continue
  run_one "$test" "" "المترجم" "ناجح"
  run_one "$test" "--مفسر" "المفسر" "ناجح"
done

run_one "src/رئيسي.نيفا" "" "المترجم" "حزم ٠٫١٫٠-تطوير"
run_one "src/رئيسي.نيفا" "--مفسر" "المفسر" "حزم ٠٫١٫٠-تطوير"

echo "النتيجة: $passed ناجح، $failed فاشل"
if [ "$failed" -gt 0 ]; then
  exit 1
fi
