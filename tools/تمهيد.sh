#!/bin/sh
# تمهيد بيئة تشغيل Niva لـ «حزم»
# ينزّل ثنائي Runtime المثبّت من إصدارات مستودع RIO4140/niva
# دون استنساخ مستودع اللغة كاملا.
# الإصدار المثبّت: Niva v1.2.2 (الرأس 84fa6364) — انظر RUNTIME-COMPAT.
# أسماء الأصول كما هي فعلا في الإصدار (البادئة العربية «نيفا» سقطت من أسماء
# ثنائيات CLI في مهمة النشر — وهذه الأسماء الحقيقية لا غيرها).
set -eu

VERSION="v1.2.2"
BASE_URL="https://github.com/RIO4140/niva/releases/download/${VERSION}"
DEST_DIR="$HOME/.local/bin"
DEST="$DEST_DIR/نيفا"

case "$(uname -s)" in
  Linux)
    ASSET="default.-linux-x86_64"
    EXPECTED_SIZE="6210512"
    ;;
  Darwin)
    ASSET="default.-macos-x86_64"
    EXPECTED_SIZE="5218704"
    ;;
  *)
    echo "نظام غير مدعوم بهذا السكربت — نزّل الثنائي يدويا من صفحة الإصدار:"
    echo "https://github.com/RIO4140/niva/releases/tag/v1.2.2"
    echo "ويندوز: -windows-x86_64.exe (4877312 بايت)"
    exit 1
    ;;
esac

if [ -n "${NIVA_RUNTIME_URL:-}" ]; then
  URL="$NIVA_RUNTIME_URL"
  EXPECTED_SIZE=""
  echo "يستخدم رابطا مخصصا للثنائي (من المتغير NIVA_RUNTIME_URL)"
else
  URL="$BASE_URL/$ASSET"
fi

echo "ينزّل ثنائي Niva ${VERSION} من:"
echo "$URL"
mkdir -p "$DEST_DIR"
TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT INT TERM
curl -fL --max-time 300 -o "$TMP" "$URL"

if [ -n "$EXPECTED_SIZE" ]; then
  ACTUAL_SIZE="$(wc -c < "$TMP" | tr -d ' ')"
  if [ "$ACTUAL_SIZE" != "$EXPECTED_SIZE" ]; then
    echo "الحجم لا يطابق المتوقع: وصل $ACTUAL_SIZE بايت والمتوقع $EXPECTED_SIZE بايت — أوقف التنزيل"
    exit 1
  fi
fi

chmod +x "$TMP"
mv "$TMP" "$DEST"
trap - EXIT INT TERM
echo "ثبّت الثنائي في: $DEST"
"$DEST" --نسخة
echo "التمهيد اكتمل — جرّب: نيفا src/رئيسي.نيفا"
