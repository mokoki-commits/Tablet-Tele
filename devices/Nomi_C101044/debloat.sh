#!/bin/bash
# Безопасный деблоат для Nomi C101044

# Отключаем Google мусор и лишние сервисы
adb shell pm uninstall -k --user 0 com.google.android.apps.docs
adb shell pm uninstall -k --user 0 com.google.android.apps.maps
adb shell pm uninstall -k --user 0 com.google.android.apps.photos
adb shell pm uninstall -k --user 0 com.google.android.apps.tachyon
adb shell pm uninstall -k --user 0 com.google.android.videos
adb shell pm uninstall -k --user 0 com.google.android.music
adb shell pm uninstall -k --user 0 com.google.android.googlequicksearchbox
adb shell pm uninstall -k --user 0 com.google.android.youtube
adb shell pm uninstall -k --user 0 com.android.fmradio
adb shell pm uninstall -k --user 0 com.ecoflow
adb shell pm uninstall -k --user 0 com.android.wallpaperbackup
adb shell pm uninstall -k --user 0 com.android.wallpapercropper
adb shell pm uninstall -k --user 0 com.android.wallpaperpicker
adb shell pm uninstall -k --user 0 com.android.dreams.basic
adb shell pm uninstall -k --user 0 com.fota.pro
adb shell pm uninstall -k --user 0 com.google.android.configupdater
adb shell pm uninstall -k --user 0 com.rock.gota

# Ускорение анимаций
adb shell settings put global window_animation_scale 0.5
adb shell settings put global transition_animation_scale 0.5
adb shell settings put global animator_duration_scale 0.5

echo "Оптимизация завершена."
