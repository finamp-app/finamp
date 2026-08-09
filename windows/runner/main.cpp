#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "app_links/app_links_plugin_c_api.h"
#include "flutter_window.h"
#include "utils.h"

bool SendAppLinkToInstance(const std::wstring& title) {
  // Find our exact window
  HWND hwnd = nullptr;
  struct EnumData {
    std::wstring needle;
    HWND found = nullptr;
  } data{title, nullptr};

  EnumWindows([](HWND w, LPARAM lp) -> BOOL {
    auto* d = reinterpret_cast<EnumData*>(lp);
    if (!IsWindowVisible(w)) return TRUE;
    wchar_t cls[256];
    if (!GetClassName(w, cls, 256)) return TRUE;
    if (wcscmp(cls, L"FLUTTER_RUNNER_WIN32_WINDOW") != 0) return TRUE;
    wchar_t buf[512];
    if (!GetWindowText(w, buf, 512)) return TRUE;
    if (std::wstring(buf).find(d->needle) != std::wstring::npos) {
      d->found = w;
      return FALSE; // stop enumeration
    }
    return TRUE; // continue
  }, reinterpret_cast<LPARAM>(&data));

  hwnd = data.found;

  if (hwnd) {
    // Dispatch new link to current window
    SendAppLink(hwnd);

    // (Optional) Restore our window to front in same state
    WINDOWPLACEMENT place = { sizeof(WINDOWPLACEMENT) };
    GetWindowPlacement(hwnd, &place);

    switch(place.showCmd) {
      case SW_SHOWMAXIMIZED:
          ShowWindow(hwnd, SW_SHOWMAXIMIZED);
          break;
      case SW_SHOWMINIMIZED:
          ShowWindow(hwnd, SW_RESTORE);
          break;
      default:
          ShowWindow(hwnd, SW_NORMAL);
          break;
    }

    SetWindowPos(0, HWND_TOP, 0, 0, 0, 0, SWP_SHOWWINDOW | SWP_NOSIZE | SWP_NOMOVE);
    SetForegroundWindow(hwnd);
    // END (Optional) Restore

    // Window has been found, don't create another one.
    return true;
  }

  return false;
}

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {

  // You may ignore the result if you need to create another window.
  if (SendAppLinkToInstance(L"Finamp")) {
    return EXIT_SUCCESS;
  }
                        
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(300, 300);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"Finamp", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
