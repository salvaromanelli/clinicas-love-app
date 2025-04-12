import Flutter
import ARKit

public class FaceMeshChannelRegistrar {
  public static func register(with registrar: FlutterPluginRegistrar) {
    // Register the face mesh channel
    FaceMeshGeometryHandler.registerChannel(messenger: registrar.messenger())
  }
}