#!/bin/sh
# تشغيل اختبارات حزم: كل برنامج اختبار .نيفا يعمل في الوضعين
# (المترجم الافتراضي والمفسر التشخيصي) في مجلد مؤقت جديد تماما،
# والناجح هو الذي يطبع «ناجح». مجلد جديد لكل تشغيل لأن اختبار
# المخزن يبدأ من مخزن فارغ في الوضعين معا.
# لا إطار اختبار في لغة Niva بعد — فالسكربت يحكم.
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
trap 'rm -rf "$TMPROOT"' EXIT INT TERM
passed=0
failed=0

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
  if [ -z "$mode_flag" ]; then
    out="$("$NIVA" "$dir/$base" 2>/dev/null)"
  else
    out="$("$NIVA" "$mode_flag" "$dir/$base" 2>/dev/null)"
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
