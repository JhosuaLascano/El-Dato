import SwiftUI
import WidgetKit

// MARK: - Datos (los escribe la app en el App Group)

struct PendingItem: Decodable, Hashable {
  let title: String
  let kind: String
  let due: Double
  let amount: String
}

struct WidgetData: Decodable {
  let balance: String
  let today: String
  let pendingCount: Int
  let overdueCount: Int
  let pending: [PendingItem]

  static let sample = WidgetData(
    balance: "$ 187,50", today: "$ 12,50", pendingCount: 3, overdueCount: 1,
    pending: [
      PendingItem(title: "Pagar internet", kind: "pago", due: (Date().timeIntervalSince1970 - 86400) * 1000, amount: "$ 25,00"),
      PendingItem(title: "Entregar informe", kind: "tarea", due: (Date().timeIntervalSince1970 + 3600) * 1000, amount: ""),
      PendingItem(title: "Comprar víveres", kind: "compra", due: (Date().timeIntervalSince1970 + 90000) * 1000, amount: "$ 40,00"),
    ])

  static let empty = WidgetData(balance: "$ 0,00", today: "$ 0,00", pendingCount: 0, overdueCount: 0, pending: [])
}

enum SharedStore {
  static let defaultGroup = "group.com.ladata.elDato"
  static let dataKey = "widget_data"

  static func group() -> String {
    var candidates: [String] = []
    if let alt = Bundle.main.object(forInfoDictionaryKey: "ALTAppGroups") as? [String] { candidates += alt }
    candidates += provisionedGroups()
    candidates.append(defaultGroup)
    return candidates.first {
      FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: $0) != nil
    } ?? defaultGroup
  }

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

  static func load() -> WidgetData {
    guard let json = UserDefaults(suiteName: group())?.string(forKey: dataKey),
          let d = try? JSONDecoder().decode(WidgetData.self, from: Data(json.utf8)) else { return .empty }
    return d
  }
}

// MARK: - Línea de tiempo

struct Entry: TimelineEntry {
  let date: Date
  let data: WidgetData
}

struct Provider: TimelineProvider {
  func placeholder(in context: Context) -> Entry { Entry(date: Date(), data: .sample) }

  func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) {
    let d = SharedStore.load()
    completion(Entry(date: Date(), data: context.isPreview && d.pendingCount == 0 ? .sample : d))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
    let now = Date()
    let data = SharedStore.load()
    // Una entrada cada 30 min para que "Hoy / Mañana / Vencido" se mantengan al día.
    let entries = (0..<8).map { Entry(date: now.addingTimeInterval(Double($0) * 1800), data: data) }
    completion(Timeline(entries: entries, policy: .atEnd))
  }
}

// MARK: - Estilo El Dato

extension Color {
  static let gold = Color(red: 0.949, green: 0.776, blue: 0.294)
  static let wBg = Color(red: 0.086, green: 0.082, blue: 0.059)
  static let wLine = Color(red: 0.173, green: 0.165, blue: 0.118)
  static let wText = Color(red: 0.953, green: 0.933, blue: 0.878)
  static let wMuted = Color(red: 0.604, green: 0.580, blue: 0.514)
  static let wRed = Color(red: 1.0, green: 0.420, blue: 0.369)
}

enum Links {
  static let add = URL(string: "eldato://add")!
  static let reminders = URL(string: "eldato://reminders")!
}

func kindIcon(_ k: String) -> String {
  switch k {
  case "pago": return "creditcard.fill"
  case "compra": return "cart.fill"
  case "tarea": return "checkmark.circle.fill"
  default: return "bell.fill"
  }
}

func dueText(_ ms: Double, now: Date) -> (String, Bool) {
  let d = Date(timeIntervalSince1970: ms / 1000)
  let cal = Calendar.current
  let f = DateFormatter()
  f.locale = Locale(identifier: "es")
  f.dateFormat = "HH:mm"
  let hour = f.string(from: d)
  if d < now {
    if cal.isDateInToday(d) { return ("Vencido · hoy \(hour)", true) }
    if cal.isDateInYesterday(d) { return ("Vencido · ayer", true) }
    f.dateFormat = "d MMM"
    return ("Vencido · \(f.string(from: d))", true)
  }
  if cal.isDateInToday(d) { return ("Hoy · \(hour)", false) }
  if cal.isDateInTomorrow(d) { return ("Mañana · \(hour)", false) }
  f.dateFormat = "EEE d MMM"
  return (f.string(from: d).capitalized, false)
}

extension View {
  @ViewBuilder func elDatoBackground() -> some View {
    if #available(iOSApplicationExtension 17.0, *) {
      containerBackground(Color.wBg, for: .widget)
    } else {
      padding().background(Color.wBg)
    }
  }
}

// MARK: - Piezas

struct Coin: View {
  var size: CGFloat
  var body: some View { Image("Coin").resizable().scaledToFit().frame(width: size, height: size) }
}

struct AddButton: View {
  var title: String
  var height: CGFloat
  var body: some View {
    Link(destination: Links.add) {
      HStack(spacing: 6) {
        Image(systemName: "plus").font(.system(size: height * 0.38, weight: .heavy))
        Text(title).font(.system(size: height * 0.34, weight: .bold, design: .rounded)).lineLimit(1)
      }
      .foregroundColor(Color(red: 0.1, green: 0.08, blue: 0))
      .frame(maxWidth: .infinity)
      .frame(height: height)
      .background(Capsule().fill(Color.gold))
    }
  }
}

struct Header: View {
  let data: WidgetData
  var body: some View {
    HStack(spacing: 10) {
      Coin(size: 34)
      VStack(alignment: .leading, spacing: 1) {
        Text("EL DATO").font(.system(size: 14, weight: .heavy, design: .rounded)).foregroundColor(.gold).tracking(0.6)
        Text("Hoy gastaste \(data.today)").font(.system(size: 11.5, weight: .medium)).foregroundColor(.wMuted).lineLimit(1)
      }
      Spacer(minLength: 4)
      VStack(alignment: .trailing, spacing: 1) {
        Text("Saldo").font(.system(size: 11.5, weight: .medium)).foregroundColor(.wMuted)
        Text(data.balance).font(.system(size: 18, weight: .heavy, design: .rounded)).foregroundColor(.wText)
          .minimumScaleFactor(0.6).lineLimit(1)
      }
    }
  }
}

struct PendingRow: View {
  let item: PendingItem
  let now: Date
  var body: some View {
    let (when, overdue) = dueText(item.due, now: now)
    HStack(spacing: 10) {
      Image(systemName: kindIcon(item.kind))
        .font(.system(size: 13, weight: .semibold))
        .foregroundColor(overdue ? .wRed : .gold)
        .frame(width: 28, height: 28)
        .background(RoundedRectangle(cornerRadius: 9).fill((overdue ? Color.wRed : Color.gold).opacity(0.16)))
      VStack(alignment: .leading, spacing: 1) {
        Text(item.title).font(.system(size: 13, weight: .semibold)).foregroundColor(.wText).lineLimit(1)
        Text(when).font(.system(size: 11.5, weight: .medium)).foregroundColor(overdue ? .wRed : .wMuted).lineLimit(1)
      }
      Spacer(minLength: 4)
      if !item.amount.isEmpty {
        Text(item.amount).font(.system(size: 13, weight: .bold, design: .rounded)).foregroundColor(.wText)
      }
    }
  }
}

func summary(_ d: WidgetData) -> String {
  if d.pendingCount == 0 { return "Sin pendientes" }
  let p = d.pendingCount == 1 ? "1 pendiente" : "\(d.pendingCount) pendientes"
  return d.overdueCount > 0 ? "\(p) · \(d.overdueCount) vencido\(d.overdueCount == 1 ? "" : "s")" : p
}

// MARK: - Tamaños

struct SmallView: View {
  let data: WidgetData
  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack(spacing: 8) {
        Coin(size: 28)
        VStack(alignment: .leading, spacing: 0) {
          Text("Saldo").font(.system(size: 11, weight: .medium)).foregroundColor(.wMuted)
          Text(data.balance).font(.system(size: 16, weight: .heavy, design: .rounded)).foregroundColor(.wText)
            .minimumScaleFactor(0.5).lineLimit(1)
        }
      }
      Spacer(minLength: 6)
      HStack(spacing: 4) {
        Text("\(data.pendingCount)").font(.system(size: 13, weight: .heavy)).foregroundColor(.gold)
        Text(data.pendingCount == 1 ? "pendiente" : "pendientes").font(.system(size: 12, weight: .medium)).foregroundColor(.wMuted)
      }
      if data.overdueCount > 0 {
        Text("\(data.overdueCount) vencido\(data.overdueCount == 1 ? "" : "s")").font(.system(size: 11.5, weight: .semibold)).foregroundColor(.wRed)
      }
      Spacer(minLength: 6)
      AddButton(title: "Gasto", height: 36)
    }
    .widgetURL(Links.add)
  }
}

struct MediumView: View {
  let data: WidgetData
  let now: Date
  var body: some View {
    VStack(spacing: 10) {
      Header(data: data)
      HStack(spacing: 10) {
        AddButton(title: "Agregar gasto", height: 40)
        Link(destination: Links.reminders) {
          VStack(alignment: .leading, spacing: 1) {
            Text("Pendientes").font(.system(size: 11, weight: .medium)).foregroundColor(.wMuted)
            if let first = data.pending.first {
              Text(first.title).font(.system(size: 12.5, weight: .semibold)).foregroundColor(.wText).lineLimit(1)
              let (when, overdue) = dueText(first.due, now: now)
              Text(data.pendingCount > 1 ? "\(when) · +\(data.pendingCount - 1)" : when)
                .font(.system(size: 11, weight: .medium)).foregroundColor(overdue ? .wRed : .wMuted).lineLimit(1)
            } else {
              Text("Todo al día").font(.system(size: 12.5, weight: .semibold)).foregroundColor(.wText)
            }
          }
          .frame(maxWidth: .infinity, alignment: .leading)
        }
      }
    }
    .widgetURL(Links.reminders)
  }
}

struct LargeView: View {
  let data: WidgetData
  let now: Date
  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      Header(data: data)
      AddButton(title: "Agregar gasto", height: 46).padding(.top, 14).padding(.bottom, 12)
      HStack {
        Text("Pendientes").font(.system(size: 14, weight: .bold)).foregroundColor(.wText)
        Spacer()
        Text(summary(data)).font(.system(size: 12, weight: .medium)).foregroundColor(.wMuted)
      }
      .padding(.bottom, 4)
      if data.pending.isEmpty {
        Spacer()
        HStack {
          Spacer()
          VStack(spacing: 6) {
            Image(systemName: "checkmark.seal.fill").font(.system(size: 26)).foregroundColor(.gold)
            Text("Todo al día").font(.system(size: 13, weight: .semibold)).foregroundColor(.wMuted)
          }
          Spacer()
        }
      } else {
        ForEach(data.pending.prefix(3), id: \.self) { item in
          Rectangle().fill(Color.wLine).frame(height: 1)
          PendingRow(item: item, now: now).padding(.vertical, 7)
        }
      }
      Spacer(minLength: 0)
    }
    .widgetURL(Links.reminders)
  }
}

struct ElDatoWidgetView: View {
  @Environment(\.widgetFamily) var family
  let entry: Entry
  var body: some View {
    Group {
      switch family {
      case .systemSmall: SmallView(data: entry.data)
      case .systemMedium: MediumView(data: entry.data, now: entry.date)
      default: LargeView(data: entry.data, now: entry.date)
      }
    }
    .elDatoBackground()
  }
}

@main
struct ElDatoWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "ElDatoWidget", provider: Provider()) { entry in
      ElDatoWidgetView(entry: entry)
    }
    .configurationDisplayName("El Dato")
    .description("Tu saldo, agregar gasto y tus pendientes.")
    .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
  }
}
