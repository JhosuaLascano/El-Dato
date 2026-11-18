package com.ladata.el_dato

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.view.View
import android.widget.RemoteViews
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale

/** Datos del widget: los escribe la app (Flutter) por el canal "el_dato/widget". */
object WidgetStore {
    private const val PREFS = "el_dato_widget"
    private const val KEY = "widget_data"

    fun save(ctx: Context, json: String) {
        ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putString(KEY, json).apply()
    }

    fun load(ctx: Context): JSONObject? = try {
        ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(KEY, null)?.let { JSONObject(it) }
    } catch (_: Exception) {
        null
    }
}

object ElDatoWidgets {
    private const val GOLD = 0xFFF2C64B.toInt()
    private const val RED = 0xFFFF6B5E.toInt()
    private const val MUTED = 0xFF9A9483.toInt()

    fun refreshAll(ctx: Context) {
        val mgr = AppWidgetManager.getInstance(ctx)
        for (cls in listOf(ElDatoWidgetLarge::class.java, ElDatoWidgetSmall::class.java)) {
            val ids = mgr.getAppWidgetIds(ComponentName(ctx, cls))
            if (ids.isEmpty()) continue
            val large = cls == ElDatoWidgetLarge::class.java
            ids.forEach { mgr.updateAppWidget(it, build(ctx, large)) }
        }
    }

    private fun open(ctx: Context, action: String, req: Int): PendingIntent {
        val i = Intent(ctx, MainActivity::class.java)
            .setAction("com.ladata.el_dato.WIDGET_$action")
            .putExtra(MainActivity.EXTRA_ACTION, action)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        return PendingIntent.getActivity(ctx, req, i, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    }

    private fun summary(pending: Int, overdue: Int): String {
        if (pending == 0) return "Sin pendientes"
        val p = if (pending == 1) "1 pendiente" else "$pending pendientes"
        return if (overdue > 0) "$p · $overdue vencido${if (overdue == 1) "" else "s"}" else p
    }

    private fun kindIcon(kind: String) = when (kind) {
        "pago" -> R.drawable.ic_w_pago
        "compra" -> R.drawable.ic_w_compra
        "tarea" -> R.drawable.ic_w_tarea
        else -> R.drawable.ic_w_otro
    }

    /** Texto de vencimiento calculado al momento: "Hoy · 17:00", "Mañana · 10:00", "Vencido · ayer". */
    private fun dueText(ms: Long): Pair<String, Boolean> {
        val es = Locale("es")
        val now = Calendar.getInstance()
        val d = Calendar.getInstance().apply { timeInMillis = ms }
        val hour = SimpleDateFormat("HH:mm", es).format(Date(ms))
        fun dayDiff(): Int {
            val a = Calendar.getInstance().apply { timeInMillis = ms; set(Calendar.HOUR_OF_DAY, 12); set(Calendar.MINUTE, 0) }
            val b = Calendar.getInstance().apply { set(Calendar.HOUR_OF_DAY, 12); set(Calendar.MINUTE, 0) }
            return Math.round((a.timeInMillis - b.timeInMillis) / 86_400_000.0).toInt()
        }
        val diff = dayDiff()
        if (d.before(now)) {
            return when (diff) {
                0 -> "Vencido · hoy $hour" to true
                -1 -> "Vencido · ayer" to true
                else -> "Vencido · ${SimpleDateFormat("d MMM", es).format(Date(ms))}" to true
            }
        }
        return when (diff) {
            0 -> "Hoy · $hour" to false
            1 -> "Mañana · $hour" to false
            else -> SimpleDateFormat("EEE d MMM", es).format(Date(ms)).replaceFirstChar { it.uppercase() } to false
        }
    }

    fun build(ctx: Context, large: Boolean): RemoteViews {
        val data = WidgetStore.load(ctx)
        val balance = data?.optString("balance", "$ 0,00") ?: "$ 0,00"
        val today = data?.optString("today", "$ 0,00") ?: "$ 0,00"
        val pendingCount = data?.optInt("pendingCount", 0) ?: 0
        val overdue = data?.optInt("overdueCount", 0) ?: 0
        val list = data?.optJSONArray("pending")

        val v = RemoteViews(ctx.packageName, if (large) R.layout.widget_large else R.layout.widget_small)
        v.setTextViewText(R.id.balance, balance)
        v.setOnClickPendingIntent(R.id.btn_add, open(ctx, "add", 1))

        if (!large) {
            v.setTextViewText(R.id.summary, summary(pendingCount, overdue))
            v.setTextColor(R.id.summary, if (overdue > 0) RED else MUTED)
            v.setOnClickPendingIntent(R.id.root, open(ctx, "reminders", 2))
            return v
        }

        v.setTextViewText(R.id.today, "Hoy gastaste $today")
        v.setTextViewText(R.id.summary, summary(pendingCount, overdue))
        v.setOnClickPendingIntent(R.id.root, open(ctx, "reminders", 2))
        v.removeAllViews(R.id.list)
        val n = minOf(list?.length() ?: 0, 3)
        v.setViewVisibility(R.id.empty, if (n == 0) View.VISIBLE else View.GONE)
        for (i in 0 until n) {
            val p = list!!.getJSONObject(i)
            val (whenText, late) = dueText(p.optLong("due"))
            val row = RemoteViews(ctx.packageName, R.layout.widget_row)
            row.setImageViewResource(R.id.r_icon, kindIcon(p.optString("kind")))
            row.setInt(R.id.r_icon, "setColorFilter", if (late) RED else GOLD)
            row.setInt(R.id.r_icon, "setBackgroundResource", if (late) R.drawable.widget_icon_bg_red else R.drawable.widget_icon_bg)
            row.setTextViewText(R.id.r_title, p.optString("title"))
            row.setTextViewText(R.id.r_when, whenText)
            row.setTextColor(R.id.r_when, if (late) RED else MUTED)
            val amount = p.optString("amount")
            row.setTextViewText(R.id.r_amount, amount)
            row.setViewVisibility(R.id.r_amount, if (amount.isEmpty()) View.GONE else View.VISIBLE)
            v.addView(R.id.list, row)
        }
        return v
    }
}

/** Widget grande (4×3): saldo, agregar gasto y próximos pendientes. */
class ElDatoWidgetLarge : AppWidgetProvider() {
    override fun onUpdate(ctx: Context, mgr: AppWidgetManager, ids: IntArray) {
        ids.forEach { mgr.updateAppWidget(it, ElDatoWidgets.build(ctx, true)) }
    }
}

/** Widget pequeño (2×2): saldo, pendientes y botón de gasto. */
class ElDatoWidgetSmall : AppWidgetProvider() {
    override fun onUpdate(ctx: Context, mgr: AppWidgetManager, ids: IntArray) {
        ids.forEach { mgr.updateAppWidget(it, ElDatoWidgets.build(ctx, false)) }
    }
}
