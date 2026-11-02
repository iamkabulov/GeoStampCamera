# GeoStampCamera

iOS-приложение (SwiftUI, iOS 16+): снимает фото и видео и накладывает на них дату/время и геолокацию (координаты, точность, адрес). Результат сохраняется в галерею.

## Запуск
```bash
brew install xcodegen
xcodegen generate
open GeoStampCamera.xcodeproj
```
В Xcode выбрать Team в Signing & Capabilities и запустить на реальном устройстве (в симуляторе нет камеры).

## Структура
- `App/` — точка входа
- `Camera/CameraService.swift` — AVCaptureSession, фото/видео, сохранение в Photos
- `Camera/CameraView.swift` — UI: превью, живой штамп, переключатель режима, затвор
- `Location/LocationService.swift` — CoreLocation + обратное геокодирование
- `Overlay/StampRenderer.swift` — отрисовка штампа на фото (UIGraphicsImageRenderer) и видео (AVVideoComposition + CoreAnimation, время тикает каждую секунду)
