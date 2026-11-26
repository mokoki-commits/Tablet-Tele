# Nomi C101044

- **OS:** Android 8.1.0
- **Chipset:** MediaTek

## Особенности
- Сильно зависит от служб телефонии. Удаление `com.android.phone` или `com.android.providers.telephony` приводит к циклической перезагрузке (bootloop).

## Скрипты
- `debloat.sh`: Безопасная очистка (без служб связи).
