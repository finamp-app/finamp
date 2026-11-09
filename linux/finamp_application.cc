#include "finamp_application.h"

#include <flutter_linux/flutter_linux.h>
#ifdef GDK_WINDOWING_X11
#include <gdk/gdkx.h>
#endif

#include "flutter/generated_plugin_registrant.h"

struct _FinampApplication {
  GtkApplication parent_instance;
  char** dart_entrypoint_arguments;
};

G_DEFINE_TYPE(FinampApplication, finamp_application, GTK_TYPE_APPLICATION);

// Implements GApplication::activate.
static void finamp_application_activate(GApplication* application) {
  FinampApplication* self = FINAMP_APPLICATION(application);

  // handle link handling
  GList* windows = gtk_application_get_windows(GTK_APPLICATION(application));
  if (windows) {
      // If there is already a window, we just present it and do not create a new one.
      // Also call gtk_widget_show in case the window was hidden to the system tray.
    gtk_widget_show(GTK_WIDGET(windows->data));
    gtk_window_present(GTK_WINDOW(windows->data));
    return;
  }

  GtkWindow* window =
      GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));

  // Use a header bar when running in GNOME as this is the common style used
  // by applications and is the setup most users will be using (e.g. Ubuntu
  // desktop).
  // If running on X and not using GNOME then just use a traditional title bar
  // in case the window manager does more exotic layout, e.g. tiling.
  // If running on Wayland, never show the header bar, as this should generally work.
  gboolean use_header_bar = FALSE;
#ifdef GDK_WINDOWING_X11
  GdkScreen* screen = gtk_window_get_screen(window);
  if (GDK_IS_X11_SCREEN(screen)) {
    const gchar* wm_name = gdk_x11_screen_get_window_manager_name(screen);
    if (g_strcmp0(wm_name, "GNOME Shell") == 0) {
      use_header_bar = TRUE;
    }
  }
#endif
  if (use_header_bar) {
    GtkHeaderBar* header_bar = GTK_HEADER_BAR(gtk_header_bar_new());
    gtk_widget_show(GTK_WIDGET(header_bar));
    gtk_header_bar_set_title(header_bar, "Finamp");
    gtk_header_bar_set_show_close_button(header_bar, TRUE);
    gtk_window_set_titlebar(window, GTK_WIDGET(header_bar));
  } else {
    gtk_window_set_title(window, "Finamp");
  }

  gtk_window_set_default_size(window, 1280, 720);
  gtk_widget_show(GTK_WIDGET(window));

  g_autoptr(FlDartProject) project = fl_dart_project_new();
  fl_dart_project_set_dart_entrypoint_arguments(project, self->dart_entrypoint_arguments);

  FlView* view = fl_view_new(project);
  gtk_widget_show(GTK_WIDGET(view));
  gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(view));

  fl_register_plugins(FL_PLUGIN_REGISTRY(view));

  gtk_widget_grab_focus(GTK_WIDGET(view));
}

// Implements GApplication::local_command_line.
static gboolean finamp_application_local_command_line(GApplication* application, gchar*** arguments, int* exit_status) {
  FinampApplication* self = FINAMP_APPLICATION(application);
  // Strip out the first argument as it is the binary name.
  self->dart_entrypoint_arguments = g_strdupv(*arguments + 1);

  g_autoptr(GError) error = nullptr;
  if (!g_application_register(application, nullptr, &error)) {
     g_warning("Failed to register: %s", error->message);
     *exit_status = 1;
     return TRUE;
  }

  g_application_activate(application);
  *exit_status = 0;

  return FALSE; // We handled the command line arguments, so we return FALSE to indicate that we don't want the default handling.
}

// Implements GObject::dispose.
static void finamp_application_dispose(GObject* object) {
  FinampApplication* self = FINAMP_APPLICATION(object);
  g_clear_pointer(&self->dart_entrypoint_arguments, g_strfreev);
  G_OBJECT_CLASS(finamp_application_parent_class)->dispose(object);
}

static void finamp_application_class_init(FinampApplicationClass* klass) {
  G_APPLICATION_CLASS(klass)->activate = finamp_application_activate;
  G_APPLICATION_CLASS(klass)->local_command_line = finamp_application_local_command_line;
  G_OBJECT_CLASS(klass)->dispose = finamp_application_dispose;
}

static void finamp_application_init(FinampApplication* self) {}

FinampApplication* finamp_application_new() {
  return FINAMP_APPLICATION(g_object_new(finamp_application_get_type(),
                                     "application-id", APPLICATION_ID,
                                     "flags", G_APPLICATION_HANDLES_COMMAND_LINE | G_APPLICATION_HANDLES_OPEN,
                                     nullptr));
}
