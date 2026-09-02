package com.unicornsonlsd.finamp.widget.receiver

import es.antonborri.home_widget.HomeWidgetGlanceWidgetReceiver
import com.unicornsonlsd.finamp.widget.CircularWidget

class CircularWidgetReceiver : HomeWidgetGlanceWidgetReceiver<CircularWidget>() {
    override val glanceAppWidget = CircularWidget()
}
