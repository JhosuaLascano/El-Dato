import Flutter
import UIKit
import WidgetKit

/// Puente entre Flutter y el widget de El Dato:
/// - "update": guarda saldo y pendientes en el App Group y refresca el widget.
/// - "takeAction": devuelve la acción tocada en el widget ("add", "reminders").
/// Los toques del widget llegan como URLs eldato://add y eldato://reminders.
final class WidgetBridge: NSObject, FlutterPlugin, FlutterSceneLifeCycleDelegate {
  private var channel: FlutterMethodChannel?
  private var pendingAction: String?

  static func register(with registrar: FlutterPluginRegistrar) {
    let instance = WidgetBridge()
    let channel = FlutterMethodChannel(name: "el_dato/widget", binaryMessenger: registrar.messenger())
    instance.channel = channel
    registrar.addMethodCallDelegate(instance, channel: channel)
    registrar.addApplicationDelegate(instance)
    if #available(iOS 13.0, *) { registrar.addSceneDelegate(instance) }
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "update":
      if let json = call.arguments as? String {
        SharedStore.defaults()?.set(json, forKey: SharedStore.dataKey)
        if #available(iOS 14.0, *) { WidgetCenter.shared.reloadAllTimelines() }
      }
      result(nil)
    case "takeAction":
      let a = pendingAction
      pendingAction = nil
      result(a)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  @discardableResult
  private func open(_ url: URL?) -> Bool {
    guard let url = url, url.scheme == "eldato" else { return false }
    pendingAction = url.host ?? "home"
    // Avisa a Flutter; él pide la acción con "takeAction" (así nunca se duplica).
    channel?.invokeMethod("action", arguments: nil)
    return true
  }

  // MARK: - URLs (escenas, iOS 13+)

  @available(iOS 13.0, *)
  func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions?) -> Bool {
    if let url = connectionOptions?.urlContexts.first?.url { return open(url) }
    return false
  }

  @available(iOS 13.0, *)
  func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) -> Bool {
    return open(URLContexts.first?.url)
  }

  // Respaldo para cuando la app no usa escenas.
  func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
    return open(url)
  }
}

/// Datos compartidos con la extensión del widget mediante un App Group.
/// AltStore cambia el identificador del grupo al firmar con tu Apple ID,
/// por eso se busca el grupo real en tiempo de ejecución.
enum SharedStore {
  static let defaultGroup = "group.com.ladata.elDato"
  static let dataKey = "widget_data"

  private static var cached: String?

  static func defaults() -> UserDefaults? {
    UserDefaults(suiteName: group())
  }

  static func group() -> String {
    if let c = cached { return c }
    var candidates: [String] = []
    if let alt = Bundle.main.object(forInfoDictionaryKey: "ALTAppGroups") as? [String] { candidates += alt }
    candidates += provisionedGroups()
    candidates.append(defaultGroup)
    let found = candidates.first {
      FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: $0) != nil
    } ?? defaultGroup
    cached = found
    return found
  }

  /// Lee los App Groups del perfil con el que se firmó la app (embedded.mobileprovision).
  private static func provisionedGroups() -> [String] {
    guard let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
          let data = try? Data(contentsOf: url),
          let text = String(data: data, encoding: .isoLatin1),
          let start = text.range(of: "<?xml"),
          let end = text.range(of: "</plist>") else { return [] }
    let plist = String(text[start.lowerBound..<end.upperBound])
    guard let obj = try? PropertyListSerialization.propertyList(from: Data(plist.utf8), options: [], format: nil),
          let dict = obj as? [String: Any],
          let ent = dict["Entitlements"] as? [String: Any],
          let groups = ent["com.apple.security.application-groups"] as? [String] else { return [] }
    return groups
  }
}
