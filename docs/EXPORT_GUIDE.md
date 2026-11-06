# Dead Hours — Export & Device Testing Guide

> Target platforms: Android (APK/AAB) + iOS (IPA)
> Engine: Godot 4.x

---

## 1. Android Export

### Prerequisites
- **Godot 4.x** with Android export templates installed (Editor → Editor Menu → Manage Export Templates)
- **Java JDK 17+** (for signing)
- **Android SDK** (command-line tools minimum)
- **Android keystore** for signing

### Creating a Keystore
```bash
keytool -keyalg RSA -genkeypair -alias dead_hours \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -keystore dead_hours.keystore \
  -storepass YOUR_PASSWORD -keypass YOUR_PASSWORD \
  -dname "CN=Fabio Ritzel Borges, O=Indie, C=BR"
```

### Export Preset Configuration
| Setting | Value |
|--------|-------|
| Package name | `com.fabioritzel.deadhours` |
| Minimum SDK | API 24 (Android 7.0) |
| Target SDK | API 34 (Android 14) |
| Architecture | arm64-v8a, arm32, x86_64 |
| Export format | AAB (for Play Store) or APK (for testing) |
| Keystore | Path to dead_hours.keystore |
| Screen orientation | Portrait or Landscape (as designed) |
| | |
| **Godot settings** | |
| Renderer | `gl_compatibility` (for broad device support) |
| Texture compression | ETC2 (Android standard) |
| Anti-aliasing | MSAA 2x (mobile performance) |

### Godot Export Config (export_presets.cfg)
```ini
[preset.0]
name="Android"
platform="Android"
runnable=true
custom_features=""
export_filter="all_resources"
...
[preset.0.options]
package/name="Dead Hours"
package/unique_name="com.fabioritzel.deadhours"
version/code=1
version/name="1.0"
architectures/armeabi-v7a=true
architectures/arm64-v8a=true
architectures/x86_64=false
keystore/debug=""
keystore/debug_user=""
keystore/debug_password=""
keystore/release="dead_hours.keystore"
keystore/release_user="dead_hours"
keystore/release_password="YOUR_PASSWORD"
graphics/32_bits=true
graphics/opengl_debug=false
xr_features/xr_mode=0
```

### Testing Checklist — Android
- [ ] App installs on Android 7+ device
- [ ] App launches without black screen
- [ ] Touch controls respond correctly (joystick + tap)
- [ ] Touch coordinates align with visual elements (no offset)
- [ ] Portrait mode displays correctly (no stretching)
- [ ] Save game persists after app close
- [ ] Save game persists after device restart
- [ ] Audio plays through speaker and headphones
- [ ] No audio stuttering during scene transitions
- [ ] Portrait images load without distortion
- [ ] Vignette/shader effects render on older devices
- [ ] No crashes during 10-minute play session
- [ ] Back button pauses game (doesn't quit)
- [ ] Memory usage stays under 512MB

---

## 2. iOS Export

### Prerequisites
- **macOS** with Xcode 15+
- **Godot 4.x** with iOS export templates
- **Apple Developer account** ($99/year)
- **Provisioning profile** + signing certificate
- **App ID** registered in Apple Developer Portal

### Export Preset Configuration
| Setting | Value |
|--------|-------|
| Bundle identifier | `com.fabioritzel.deadhours` |
| Minimum iOS version | 14.0 |
| Architecture | arm64 |
| Export format | IPA (for App Store) or Xcode project (for testing) |
| | |
| **Godot settings** | |
| Renderer | `gl_compatibility` |
| Texture compression | ASTC (iOS standard) |
| Orientation | Portrait or Landscape (match Android) |

### Testing Checklist — iOS
- [ ] App installs via TestFlight or Xcode
- [ ] App launches without black screen
- [ ] Touch controls respond correctly
- [ ] Safe area respected (notch / Dynamic Island)
- [ ] Save game persists after app swipe-close
- [ ] Audio plays through speaker and AirPods
- [ ] No crashes during 10-minute play session
- [ ] App follows iOS HIG (back gesture, swipe to go back)
- [ ] App handles phone call interruption (audio pauses)
- [ ] App handles backgrounding (saves state)
- [ ] Portrait images display correctly
- [ ] Memory usage stays under 200MB (iOS is stricter)

---

## 3. Common Issues & Solutions

### Black screen on launch
**Cause:** Missing export templates or wrong renderer.
**Fix:** Ensure `gl_compatibility` renderer is selected. Install mobile export templates (Editor → Manage Export Templates → Download for mobile).

### Touch offset / misaligned taps
**Cause:** Viewport size mismatch with device screen.
**Fix:** Set `viewport_width` and `viewport_height` in project.godot to match your design resolution (1280x720). Enable "Stretch → Aspect: keep_height" or "keep_width".

### Save game not persisting
**Cause:** Using `user://` path incorrectly on mobile.
**Fix:** Godot's `user://` path maps to app-private storage on Android and app documents on iOS. Don't use `res://` for saves — it's read-only on mobile.

### Audio stuttering
**Cause:** Audio files too large or not streamed.
**Fix:** Use `.ogg` (Vorbis) for music (streamed), `.wav` for short SFX (loaded in memory). Set `loop` and `stream` properties correctly in AudioStreamPlayer.

### Portraits not loading
**Cause:** Texture import settings wrong for mobile.
**Fix:** Ensure PNG files have `import` files with `compress/mode=lossy` and `mipmaps/generate=true`. Use ETC2 (Android) or ASTC (iOS) compression.

### App crashes on older devices
**Cause:** Too much memory or unsupported shader features.
**Fix:** Use `gl_compatibility` renderer. Reduce texture sizes (max 2048x2048). Avoid complex shaders on low-end devices. Profile with Godot's built-in monitor.

### Shader effects not rendering
**Cause:** Some older GPUs don't support all shader features.
**Fix:** Test shaders on minimum-spec devices. Provide a fallback (disable effects if `OS.get_name()` returns mobile and device is low-end). Use simple shaders — avoid loops and texture sampling in fragment shaders.

---

## 4. Export Workflow

```
1. Test in Godot editor (PC) — verify all scenes work
2. Export APK → install on Android test device
3. Run full testing checklist
4. Fix issues
5. Export AAB → upload to Google Play Console (internal testing track)
6. Export IPA → upload to App Store Connect (TestFlight)
7. Beta test with 5-10 testers
8. Fix final issues
9. Release to production
```

---

## 5. File Sizes (Estimated)

| Component | Size |
|-----------|------|
| Godot engine (Android) | ~35 MB |
| Game scripts | ~2 MB |
| Portraits (19 images) | ~3 MB |
| Backgrounds (8 images) | ~4 MB |
| Sprites (8 frames) | ~1 MB |
| Audio (estimated) | ~10-20 MB |
| Story data (JSON) | <1 MB |
| **Total APK** | **~55-65 MB** |

This is well within the 150 MB APK limit for Google Play and the 200 MB limit for OTA App Store updates.
