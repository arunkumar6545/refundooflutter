package com.refundoo.refundoo

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin

class RefundooWidget : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (widgetId in appWidgetIds) {
            updateWidget(context, appWidgetManager, widgetId)
        }
    }

    private fun updateWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        widgetId: Int
    ) {
        val widgetData = HomeWidgetPlugin.getData(context)

        val pendingAmount  = widgetData.getString("pending_amount", "₹0") ?: "₹0"
        val pendingCount   = widgetData.getString("pending_count",  "0 refunds pending") ?: "0 refunds pending"

        val views = RemoteViews(context.packageName, R.layout.refundoo_widget).apply {
            setTextViewText(R.id.widget_amount, pendingAmount)
            setTextViewText(R.id.widget_count,  pendingCount)
        }

        appWidgetManager.updateAppWidget(widgetId, views)
    }
}
