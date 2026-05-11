// Remember to set a package in order for home_widget to find the Receiver
package com.unicornsonlsd.finamp.glance

import es.antonborri.home_widget.HomeWidgetGlanceWidgetReceiver

class HomeWidgetReceiver : HomeWidgetGlanceWidgetReceiver<HomeWidgetGlanceAppWidget>() {
    override val glanceAppWidget = HomeWidgetGlanceAppWidget()
}
