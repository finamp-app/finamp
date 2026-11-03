![Several screenshots of Finamp, featuring various screens in the app on desktop, Android, and iOS](<images/GitHub_Banner.png>)

<div align="center">
  <a href="https://play.google.com/store/apps/details?id=com.unicornsonlsd.finamp"><img src="assets/app-store-badges/play-store.png"
      alt="Get it on Google Play"
      height="80"></a>
  <a href="https://apps.apple.com/us/app/finamp/id1574922594"><img src="assets/app-store-badges/app-store.svg"
      alt="Download on the App Store"
      height="80"></a>
  <a href="https://f-droid.org/packages/com.unicornsonlsd.finamp/"><img src="assets/app-store-badges/fdroid.png"
    alt="Get it on F-Droid"
    height="80"></a>
  <br />
  <i><a href="#installing-finamp">Alternative ways to get Finamp</a></i>
</div>

## TL;DR

Finamp is a **free** Jellyfin music player for Android, iOS and Desktop. It allows you to stream and download the music you own. It has a modern but **thought-through** design, a ton of features, is customizable, and respects your **privacy**!

> [!IMPORTANT]
> You **need** access to a [Jellyfin](https://jellyfin.org) server or you **won't be able to use Finamp at all**.  
> ([Navidrome](https://github.com/navidrome/navidrome/releases/tag/v0.64.0) and [Lyra](https://github.com/lyra-org/lyra) also work, but aren't actively supported)

## Features

Finamp comes with a bunch of features, but here are the ones we think are **most interesting**:

- Gapless playback
- Download music to listen offline
- Transcoded streaming for reduced mobile data usage
- Dynamic colors based on the current track & your device's theme
- Lyrics Support
- Audio volume normalization (aka "ReplayGain")
- Android Auto & CarPlay support
- Integration with [AudioMuse](https://github.com/NeptuneHub/AudioMuse-AI) for sonic analysis and improved mixes
- [Desktop support](#other-installation-methods)
- Support for the tracking your listening via the [Playback Reporting](https://jellyfin.org/docs/general/server/plugins/#playback-reporting) plugin, even when you are offline!
- *And more for you to explore, e.g. via [our Wiki](https://github.com/finamp-app/finamp/wiki)!*

## Screenshots

![Banner with screenshots of Finamp, showing the player screen, light mode, dark mode & adaptive theme colors, and the downloads screen. It includes the following text: Stream your music from your server, or download it for offline playback. Light & dark mode with adaptive theme](images/GitHub_Screenshots_1.png)

![Banner with screenshots of Finamp, showing the queue panel, home & library tabs, and lyrics screen. It includes the following text: Powerful queue with advanced Next Up, dedicated home tab and library browsing, time-synced lyrics support](<images/GitHub_ Screenshots_2.png>)

## Community & Discussions

Have a simple question about Finamp, or struggling with setting up your Jellyfin correctly?  
Just want someone to talk to and share your favorite music with?  
Aside from using the [Issues](https://github.com/jmshrv/finamp/issues) and [Discussions](https://github.com/jmshrv/finamp/discussions) functionality here on GitHub, you could also **[join our Finamp Beta Discord server](https://discord.gg/xh9SZ73jWk)!**  
We post release notes and announcements there too, and you'll likely get a reply more quickly there compared to GitHub.

## Installing Finamp

#### Android

- [Google Play](https://play.google.com/store/apps/details?id=com.unicornsonlsd.finamp)
- [F-Droid](https://f-droid.org/en/packages/com.unicornsonlsd.finamp/)
- `.apk`: see the [latest GitHub release](https://github.com/finamp-app/finamp/releases/latest)

#### Windows

Since the app is not available via the Microsoft Store yet, you'll have to install a self-signed certificate before you can install the [`.msix` file attached to each release](https://github.com/finamp-app/finamp/releases/latest).
**You'll only have to do this once!**

1. Download the latest `.msix` file from the [release page](https://github.com/jmshrv/finamp/releases), then navigate to the folder you downloaded it to in File Explorer
2. Right-click the package and select *Properties*
3. **Properties**: Switch to the *Digital Signatures* tab, then select `Finamp` under *Signature list* (or *Embedded Signatures*), then click *Details*
4. **Digital Signature Details**: click *View Certificate*
5. **Certificate**: click *Install Certificate...*
6. **Certificate Import Wizard**: set *Store Location* to `Local Machine`, click *Next*, then *Place ... in the following store* and browse to `Trusted People`, then *Next* and *Finish*
7. You can now close all the popups and open the MSIX file to install it!

Alternatively, you could download the [plain zip archive](https://github.com/finamp-app/finamp/releases/latest) and manually drag it into the correct place. This is however not a portable installation, since it will still create the database in your user directory.

#### Mac

- `.app`: see the [GitHub release](https://github.com/finamp-app/finamp/releases/latest)

#### Linux

- [Flathub](https://flathub.org/en/apps/com.unicornsonlsd.finamp)
- [AUR](https://aur.archlinux.org/packages/finamp)
  - Install via `yay -S finamp`

## Contributing

### Code

Just like any [FOSS software](https://en.wikipedia.org/wiki/Free_and_open-source_software) Finamp also relies on your contributions!
If you are interested you can consult the [Contribution Guidelines](https://github.com/jmshrv/finamp/blob/main/CONTRIBUTING.md) to get started. Anything helps!

If you have any questions, just reach out to us on GitHub or [Discord](https://discord.gg/xh9SZ73jWk) (`#contributing`)`!

### Translations

You can also help out by translating Finamp using our [weblate page](https://hosted.weblate.org/engage/finamp/). Here is the current state of translations:
<div align="center">
    <a href="https://hosted.weblate.org/engage/finamp/">
        <img src="https://hosted.weblate.org/widget/finamp/finamp/horizontal-auto.svg" alt="Translation status" />
    </a>
</div>

## FAQ - Frequently Asked Questions

### Do you accept donations?

Contributions and donations of any kind are welcome, but you can't donate to *Finamp* directly. So, if you see some new feature or fix in the release notes that you like, feel free to check if *the person that contributed that* accepts donations!

### Which formats/codecs does Finamp support?

Most. Generally speaking if Jellyfin and your device support a format, Finamp will too! In case a format doesn't work you can always enable transcoding (Finamp can transcode lossless transcoding to FLAC!).

### Does Finamp support Android Auto / Apple CarPlay?

Yes! Both are supported, but if you want to use Android Auto, you'll have to install the app via the Play Store.

### Is Finamp legal?

Yes. Finamp is a *tool* that lets you interface with a Jellyfin server. Finamp does not come with any music, and will not connect to streaming services other than Jellyfin.  
You will need to bring your own media and add it to Jellyfin, by purchasing music online or ripping discs. This often also directly supports your favorite artists!

## Bugs, Problems and Feature Requests

If you encounter any errors, issues, accessibility problems or the likes please check our [issue tracker](https://github.com/jmshrv/finamp/issues) first, and open a new issue if there isn't one already.

## Shoutout

- Thanks to all the [Contributors and Maintainer](https://github.com/jmshrv/finamp/graphs/contributors) (see bellow) who helped to make, fix and improve Finamp! Without you Finamp wouldn't be Finamp. ❤️
- Thanks to the [Jellyfin Contributors](https://jellyfin.org/contribute/) without whom Finamp wouldn't exists in the first place and thanks for making self-hosting and privacy easier!
- Thanks to all the Developers who created and maintain packages Finamp uses!
- And thank **you** for using Finamp!

<a href="https://github.com/jmshrv/finamp/graphs/contributors">
  <img src="https://contrib.rocks/image?repo=jmshrv/finamp" width="100%"/>
</a>

Name source: <https://www.reddit.com/r/jellyfin/comments/hjxshn/jellyamp_crossplatform_desktop_music_player/fwqs5i0/>

---

## Info For Advanced Users

### Dynamic Theming On Linux

On Linux, Finamp registers itself with the DBus system, which means you can send messages locally to Finamp!
This system allows you keep Finamp's color theme up to date with your dynamic color theme without restarting the app.
There are two color related "endpoints" you can call:

1. Reload the system accent color from GTK ([Settings > Layout & Theme > "Use System Accent"](https://intradeus.github.io/http-protocol-redirector?r=finamp://internal/settings/layout) needs to be *enabled*)

```sh
gdbus call \
    --session \
    --dest 'com.unicornsonlsd.FinampSettings' \
    --object-path '/com/unicornsonlsd/Finamp' \
    --method 'com.unicornsonlsd.Finamp.updateAccentColor'
```

1. Overwrite the accent color ([Settings > Layout & Theme > "Use System Accent"](https://intradeus.github.io/http-protocol-redirector?r=finamp://internal/settings/layout) needs to be *disabled*)  
  Only works when Finamp is running.

```sh
gdbus call \
    --session \
    --dest 'com.unicornsonlsd.FinampSettings' \
    --object-path '/com/unicornsonlsd/Finamp' \
    --method 'com.unicornsonlsd.Finamp.setAccentColor' \
    '#ff0000' # you can also send "default" to clear the accent color
```
