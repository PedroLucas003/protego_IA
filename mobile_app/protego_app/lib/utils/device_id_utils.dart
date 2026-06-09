/// Normaliza e compara IDs de dispositivo (camera_01, esp32cam-01, etc.).
class DeviceIdUtils {
  static String normalizar(String id) =>
      id.trim().toLowerCase().replaceAll('-', '_');

  static bool mesmoDispositivo(String a, String b) {
    if (a.isEmpty || b.isEmpty) return false;
    return normalizar(a) == normalizar(b);
  }
}
