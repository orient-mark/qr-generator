# Тестирование

[English](TESTING.md#testing)

## Проверка результата

Тесты проверяют контракт QR-данных, разбиение на страницы и сохранение файлов.
Экспортированные изображения декодируются независимо от генератора.
Для PDF проверяются готовые страницы: размеры, количество и содержимое QR-кодов.

| Проверяемая область | Файлы |
|---|---|
| Модель точки трассы и контракт данных | [test/course_qr_test.dart](../test/course_qr_test.dart) |
| PNG и чтение QR | [test/qr_exporter_test.dart](../test/qr_exporter_test.dart) |
| Геометрия, страницы и PDF | [test/print_exporter_test.dart](../test/print_exporter_test.dart), [tool/verify_pdf.py](../tool/verify_pdf.py) |
| Взаимодействие с экраном | [test/widget_test.dart](../test/widget_test.dart) |
| Общая подготовка тестов | [test/fonts.dart](../test/fonts.dart), [test/output_directory.dart](../test/output_directory.dart) |
| Дополнительная проверка целых PNG | [tool/verify_png.py](../tool/verify_png.py) |
| Запуск и очистка переносимого EXE | [tool/test_portable.ps1](../tool/test_portable.ps1) |

## Подготовка и запуск

Запускайте из корневого каталога проекта.
Для проверки PDF-файлов требуются Python 3, библиотеки Pillow и zxing-cpp, а также пакет Poppler (утилиты `pdfinfo` и `pdftoppm` должны быть доступны в переменной окружения PATH).

```powershell
flutter pub get
python -m pip install --target .dart_tool/verification Pillow zxing-cpp
flutter test --no-pub --concurrency=1
```

Чтобы использовать другой исполняемый файл Python, задайте переменную окружения `ORIENTMARK_TEST_PYTHON`.
Тест для PDF-файлов автоматически вызывает скрипт `tool/verify_pdf.py`.
Тест завершится с ошибкой, если необходимые инструменты отсутствуют либо экспортированные страницы не соответствуют ожидаемым параметрам (размеру, количеству или содержимому QR-кодов).
При тестировании экспорта файлов создаются временные директории, которые по завершении работы удаляются.

## Инструменты декодирования

**zxing2** независимо декодирует QR-коды в тестах PNG.
**zxing-cpp** читает QR-коды с готовых страниц PDF, преобразованных в изображения
утилитами Poppler. Это позволяет проверять сохранённый результат независимо
от генератора и макета.

Лицензии компонентов приведены в [THIRD_PARTY_LICENSES.md](../THIRD_PARTY_LICENSES.md#third-party-licenses).
