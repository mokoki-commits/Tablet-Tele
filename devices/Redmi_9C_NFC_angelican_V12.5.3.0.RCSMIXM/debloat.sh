#!/usr/bin/env bash
# ============================================================================
# Redmi 9C NFC (angelican / M2006C3MNG)
# MIUI V12.5.3.0.RCSMIXM · Android 11 (RP1A.200720.011)
# ----------------------------------------------------------------------------
# Деблоат и ограничение фона БЕЗ root. Все изменения обратимы.
#
#   ./debloat.sh status                # что включено/отключено, память, процессы
#   ./debloat.sh apply                 # отключить пакеты из списка (dry-run без --yes)
#   ./debloat.sh apply --with-wallpaper --yes
#   ./debloat.sh undo                  # вернуть всё как было
#
# Ограничения, проверенные на устройстве:
#   • MIUI сама поднимает Play Store обратно после force-stop — appops для
#     системных пакетов она игнорирует. Это не лечится без root.
#   • com.google.android.apps.work.oobconfig — protected package, pm отказывает.
#   • Отключение com.miui.miwallpaper освобождает ~117 МБ RSS, но может
#     сделать фон рабочего стола чёрным. Поэтому только по флагу.
#
# Facebook и мессенджеры не трогаются принципиально (см. NEVER_TOUCH).
# ============================================================================
set -uo pipefail

DEVICE_CODENAME="angelican"
MODEL="M2006C3MNG"
ADB="${ADB:-adb}"

# Инженерные/сервисные пакеты ODM и MediaTek, FM-радио, локальный бэкап,
# Mi Share, Mi Cloud SDK, живые обои и скринсейвер. Проверено: не влияют на
# звонки, NFC, камеру, банковские приложения и пуш.
DISABLE_PKGS=(
  com.longcheertel.sarauth        # SAR-сертификация ODM, 25 МБ резидентно
  com.longcheertel.cit            # инженерное меню ODM
  com.longcheertel.secretcode     # сервисные коды ODM
  com.miui.cit                    # инженерный тест MIUI
  com.mediatek.engineermode       # инженерный режим
  com.mediatek.lbs.em2.ui         # инженерка LBS
  com.mediatek.ygps               # логирование GPS
  com.android.fmradio             # FM-радио
  com.miui.freeform               # плавающие окна
  com.miui.backup                 # локальный бэкап MIUI
  com.milink.service              # Mi Share / трансляция
  com.miui.audiomonitor           # аудиомониторинг (не вывод звука)
  com.xiaomi.micloud.sdk          # синхронизация Mi Cloud
  com.android.dreams.basic        # скринсейвер
  com.android.wallpaper.livepicker
  com.android.wallpapercropper
  com.android.wallpaperpicker
)

# Требует явного согласия: может сделать фон рабочего стола чёрным.
WALLPAPER_PKGS=(
  com.miui.miwallpaper            # ~117 МБ RSS — самый крупный выигрыш из списка
)

# Ограничение фоновой работы. Эффект держится, пока MIUI не решит иначе.
APPOP_PKGS=(
  com.android.vending             # Play Store: 124 МБ + 92 МБ :background
  com.oneapps.batteryone
  com.opera.mini.native
)

# Никогда. Ни при каких флагах.
NEVER_TOUCH=(
  com.facebook.katana
  com.facebook.services
  com.facebook.appmanager
  com.facebook.system
  org.telegram.messenger
  org.thunderdog.challegram
  ua.privatbank.ap24
  ua.gov.diia.app
  ua.gov.reserveplus
  com.android.vending             # ограничиваем appops, но не отключаем
  com.google.android.gms
  com.android.nfc
  com.android.phone
  com.miui.securitycenter
  com.miui.powerkeeper
)

APPLY=0
WITH_WALLPAPER=0
CMD="status"
for arg in "$@"; do
  case "$arg" in
    -h|--help)         awk 'NR>1 && /^#/ {sub(/^# ?/,""); print; next} NR>1 {exit}' "$0"; exit 0 ;;
    --yes|-y)          APPLY=1 ;;
    --with-wallpaper)  WITH_WALLPAPER=1 ;;
    status|apply|undo) CMD="$arg" ;;
    *) echo "Неизвестный аргумент: $arg" >&2; exit 2 ;;
  esac
done

sh_() { "$ADB" shell "$@" 2>&1 | tr -d '\r'; }

die() { echo "ОШИБКА: $*" >&2; exit 1; }

# --- предохранители -----------------------------------------------------------
safety_check() {
  local bad=0 p n
  for p in "${DISABLE_PKGS[@]}" ${WITH_WALLPAPER:+${WALLPAPER_PKGS[@]}}; do
    for n in "${NEVER_TOUCH[@]}"; do
      [ "$p" = "$n" ] && { echo "ОТКАЗ: $p в списке NEVER_TOUCH" >&2; bad=1; }
    done
  done
  [ "$bad" -eq 0 ] || exit 3
}

preflight() {
  command -v "$ADB" >/dev/null || die "adb не найден (PATH или ADB=/путь/к/adb)"
  local n
  n=$("$ADB" devices | awk 'NR>1 && $2=="device"' | wc -l)
  [ "$n" -eq 1 ] || die "нужно ровно одно устройство в состоянии device, найдено: $n"
  local codename
  codename=$(sh_ getprop ro.product.device)
  [ "$codename" = "$DEVICE_CODENAME" ] || \
    die "это не $DEVICE_CODENAME, а '$codename' — скрипт для другого устройства"
  safety_check
}

# --- операции -----------------------------------------------------------------
pkg_state() {  # enabled | disabled | absent
  local p="$1"
  sh_ pm list packages "$p" | grep -qx "package:$p" || { echo absent; return; }
  if sh_ pm list packages -d | grep -qx "package:$p"; then echo disabled; else echo enabled; fi
}

cmd_status() {
  echo "== Устройство =="
  printf '  %-22s %s\n' \
    "model:"    "$(sh_ getprop ro.product.model)" \
    "device:"   "$(sh_ getprop ro.product.device)" \
    "firmware:" "$(sh_ getprop ro.build.version.incremental)" \
    "android:"  "$(sh_ getprop ro.build.version.release)" \
    "patch:"    "$(sh_ getprop ro.build.version.security_patch)" \
    "zygote:"   "$(sh_ getprop ro.zygote)" \
    "abilist:"  "$(sh_ getprop ro.product.cpu.abilist)"
  echo
  echo "== Память =="
  sh_ 'head -3 /proc/meminfo' | awk '{printf "  %-14s %6.0f МБ\n", $1, $2/1024}'
  echo "  процессов: $(sh_ 'ps -A | wc -l')"
  echo
  echo "== Топ-10 по RSS =="
  sh_ 'dumpsys meminfo 2>/dev/null' | sed -n '/Total RSS by process/,$p' | sed -n '2,11p'
  echo
  echo "== Целевые пакеты =="
  local p
  for p in "${DISABLE_PKGS[@]}" "${WALLPAPER_PKGS[@]}"; do
    printf '  %-38s %s\n' "$p" "$(pkg_state "$p")"
  done
  echo
  echo "== appops (RUN_IN_BACKGROUND) =="
  for p in "${APPOP_PKGS[@]}"; do
    printf '  %-30s %s\n' "$p" "$(sh_ cmd appops get "$p" RUN_IN_BACKGROUND | sed 's/RUN_IN_BACKGROUND: //')"
  done
}

cmd_apply() {
  local list=("${DISABLE_PKGS[@]}")
  [ "$WITH_WALLPAPER" -eq 1 ] && list+=("${WALLPAPER_PKGS[@]}")

  echo "== План =="
  local p st
  for p in "${list[@]}"; do
    st=$(pkg_state "$p")
    printf '  %-38s %s\n' "$p" "$st"
  done
  if [ "$APPLY" -ne 1 ]; then
    echo
    echo "Это dry-run. Повтори с --yes, чтобы применить."
    return 0
  fi

  echo
  echo "== Применяю =="
  for p in "${list[@]}"; do
    case "$(pkg_state "$p")" in
      enabled)  printf '  %-38s %s\n' "$p" "$(sh_ pm disable-user --user 0 "$p" | head -1)";;
      disabled) printf '  %-38s %s\n' "$p" "уже отключён";;
      absent)   printf '  %-38s %s\n' "$p" "не установлен, пропуск";;
    esac
  done

  echo
  echo "== Фон: appops =="
  for p in "${APPOP_PKGS[@]}"; do
    [ "$(pkg_state "$p")" = absent ] && continue
    sh_ cmd appops set "$p" RUN_IN_BACKGROUND ignore >/dev/null
    sh_ cmd appops set "$p" RUN_ANY_IN_BACKGROUND ignore >/dev/null
    "$ADB" shell am force-stop "$p" >/dev/null 2>&1
    printf '  %-30s %s\n' "$p" "ignore + force-stop"
  done

  echo
  echo "Готово. Откат: $0 undo"
}

cmd_undo() {
  echo "== Возвращаю =="
  local p
  for p in "${DISABLE_PKGS[@]}" "${WALLPAPER_PKGS[@]}"; do
    [ "$(pkg_state "$p")" = disabled ] || continue
    printf '  %-38s %s\n' "$p" "$(sh_ pm enable "$p" | head -1)"
  done
  for p in "${APPOP_PKGS[@]}"; do
    sh_ cmd appops set "$p" RUN_IN_BACKGROUND allow >/dev/null
    sh_ cmd appops set "$p" RUN_ANY_IN_BACKGROUND allow >/dev/null
    printf '  %-30s %s\n' "$p" "appops allow"
  done
  echo
  echo "Всё вернулось в состояние до оптимизации."
}

preflight
case "$CMD" in
  status) cmd_status ;;
  apply)  cmd_apply ;;
  undo)   cmd_undo ;;
  *) echo "Использование: $0 {status|apply|undo} [--yes] [--with-wallpaper]" >&2; exit 2 ;;
esac
