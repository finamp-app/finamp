package com.unicornsonlsd.finamp.widget.receiver

import es.antonborri.home_widget.HomeWidgetGlanceWidgetReceiver
import com.unicornsonlsd.finamp.widget.RectangularWidget

class RectangularWidgetReceiver : HomeWidgetGlanceWidgetReceiver<RectangularWidget>() {
    override val glanceAppWidget = RectangularWidget()
}
