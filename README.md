![Banner](./GitHub_Banner.png)

## Hacktoberfest

Ever thought about contributing to Finamp or Open Source in general?
Now is the time! It's Hacktober afterall!

There are a lot of things **you** can help with with regard to Finamp:

- Design Improvements
  - Help us redesign some missing screens! We have some mockups to get you started, just ask around here on GitHub or on our [Discord Server](https://discord.gg/xh9SZ73jWk)!
  - Fix visual bugs or improve the UI
- Bug Hunting
  - [Fixing bugs](https://github.com/jmshrv/finamp/issues?q=is%3Aissue%20state%3Aopen%20label%3Abug)
  - Adding reproduction steps for existing bugs
  - Finding bugs
- Translations
  - You can look at our [Weblate Project](https://hosted.weblate.org/engage/finamp/) to add missing translations
  - You can also add descriptions (i.e., where that string appears in the app) to some older translations strings in [this file](https://github.com/jmshrv/finamp/blob/redesign/lib/l10n/app_en.arb)
- Improving Documentation
  - User Documentation (Was there anything you struggled with at first when using Finamp? How did you solve it?)
  - Developer Documentation (Was there anything you struggled with when contribution code to Finamp? Add your solution to [CONTRIBUTING.md](https://github.com/jmshrv/finamp/blob/redesign/CONTRIBUTING.md))
- Improving the codebase
  - Optimizations (eg. Finamp currently consumes a lot of battery)
  - Documentation
  - Clean up
- Support
  - Help other people on our [Discord Server](https://discord.gg/xh9SZ73jWk)
  - Give feedback on [Pull Requests](https://github.com/jmshrv/finamp/pulls)
- Spread the word and get your friends to contribute :D

If you like Finamp but don't want to contribute for any reason, you can also contribute [to Jellyfin directly](https://github.com/jellyfin/jellyfin) or to upstream libraries which Finamp uses ([`just_audio`](https://github.com/ryanheise/just_audio), [`background_downloader`](https://github.com/781flyingdutchman/background_downloader/), etc.).  
That way you can help Finamp indirectly and Open Source as a whole!
Finamp can't exists without maintained and stable libraries :)

### What to do?

There's still a lot left over from our latest "Finamplify" Hackathon!
Take a look at the [Finamplify Project Board](https://github.com/users/jmshrv/projects/5) or even the full [Redesign Project Board](https://github.com/users/jmshrv/projects/2) (the latter is slightly outdated).  
You can find an overview of (hopefully) easy to tackle issues [here on GitHub](https://github.com/jmshrv/finamp/issues?q=is%3Aissue%20state%3Aopen%20label%3A%22easy%20fix%22%20no%3Aassignee). For some of those prior programming experience is definitely helpful.

Specifically, here a short list of long awaited features:

- Car Play
- Metadata editing
- Multi user/server support
- Various improvements for Finamp Desktop (Fixing shuffle, improved UI, better system integration)
- Automatic (Widget) Tests

### How to get started

>[!Important]
> **Make sure to check out the `redesign` branch (`git checkout redesign`)! This is where all development happens at the moment!**

Start by reading the ["Setting up a Development Environment" section](https://github.com/jmshrv/finamp/blob/redesign/CONTRIBUTING.md#setting-up-a-development-environment) in our contribution guidelines.  
Then, once flutter is working, you can simply do `flutter run`!
Any changes you do to the code can be applied via hot-reload by pressing `r` in the terminal. There are also first-party Flute integrations for many editors and IDEs.

If you have any questions, just reach out to us on GitHub or [Discord](https://discord.gg/xh9SZ73jWk)!

---

## Redesign Beta

We're currently in the process of redesigning Finamp to transform it into a modern, beautiful, and feature-rich music player made specifically for Jellyfin.  
You can join the beta on [Google Play](https://play.google.com/store/apps/details?id=com.unicornsonlsd.finamp) and [Apple TestFlight](https://testflight.apple.com/join/UqHTQTSs), or download the latest beta APK from the [releases page](https://github.com/jmshrv/finamp/releases).  
Please note that the beta is still work-in-progress, so the UI and functionality might be inconsistent or incomplete, and is not final. However, the beta is **fully functional and should be stable** enough for daily use.

---

**Finamp** is a Jellyfin music player for Android and iOS. It's meant to give you a similar listening experience as traditional streaming services such as Spotify and Apple Music, but for the music that you already own. It's free, open-source software, just like Jellyfin itself.  
Some of its features include:

- A welcoming user interface that looks modern & unique, but still familiar
- Downloading files for offline listening and saving mobile data. Can use transcoded downloads to save even more space.
- Transcoded streaming for saving mobile data
- Beautiful dynamic colors that adapt to your media
- Audio volume normalization ("ReplayGain") (Jellyfin 10.9+)
- Lyrics (Jellyfin 10.9+)
- Gapless playback
- Android Auto support (coming soon™)
- Full support for Jellyfin's "Playback Reporting" feature and plugin, letting you keep track of your listening activity
- Integration with [AudioMuse](https://github.com/NeptuneHub/AudioMuse-AI) for sonic analysis and improved mixes

***You need your own Jellyfin server to use Finamp. If you don't have one yet, take a look at [Jellyfin's website](https://jellyfin.org/) to learn more about it and how to set it up.***

## Getting Finamp

<div style="display: flex; align-items: center;" align="center">

[<img src="app-store-badges/fdroid.png"
    alt="Get it on F-Droid"
    height="80">](https://f-droid.org/packages/com.unicornsonlsd.finamp/)

[<img src="app-store-badges/play-store.png"
    alt="Get it on Google Play"
    height="80">](https://play.google.com/store/apps/details?id=com.unicornsonlsd.finamp)

[<img style="margin-left: 15px;" src="app-store-badges/app-store.svg"
    alt="Download on the App Store"
    height="55">](https://apps.apple.com/us/app/finamp/id1574922594)

</div>

<sup>Note: The F-Droid release may take a day or two to get updates because [F-Droid only builds once a day](https://www.f-droid.org/en/docs/FAQ_-_App_Developers/#ive-published-a-new-release-why-is-it-not-in-the-repository).</sup>  
The app is also available as an APK from the [releases page](https://github.com/jmshrv/finamp/releases).

The SHA-256 fingerprint of Finamp's signing certificate is `20:61:C5:C9:28:9C:00:02:08:81:B7:E5:33:4D:93:A0:2D:FA:4B:E9:80:AF:20:C0:5D:B4:E5:29:C8:DA:5B:54`. Google Play releases and provided APKs will be signed with this certificate. F-Droid releases will be signed with F-Droid's own signing certificates.

### Frequently Asked Questions

#### Before Installing

##### Is Finamp free?

Absolutely! It costs nothing to use. We do appreciate voluntary contributions of any kind though, be that bug reports, code, designs, or ideas for new features. You can also donate to some of the developers to show your appreciation <3

##### How can I install Finamp?

On Android, Finamp can be installed from the Google Play Store, F-Droid store, or directly by installing the APK file from GitHub.  
On iOS, you can install Finamp through Apple's App Store. Just click on the buttons above.

##### Does Finamp support my media formats?

Finamp should support all formats supported by Jellyfin. Some more advanced formats could cause issues for regular playback, but transcoding should fix these issues.

##### Does Finamp support Android Auto / Apple CarPlay?

Theoretically, but not yet. There is [an issue for this](https://github.com/jmshrv/finamp/issues/24) that contains a proof of concept for Android Auto in there, but it hasn't been tested yet. Maybe you could help out!

##### Is Finamp legal?

Yes. Finamp is a *tool* that lets you interface with a Jellyfin server. Finamp does not come with any music, and will not connect to streaming services other than Jellyfin. You will need to bring your own media and add it to Jellyfin, for example by purchasing music online. This often also directly supports your favorite artists!

#### After Installing

##### I'm having trouble with Finamp, where can I find help?

If you're experiencing software bugs or other issues with Finamp, be sure to take a look at [Finamp's issue tracker](https://github.com/jmshrv/finamp/issues), especially the pinned issues at the top of the page. If you can't find anything related to your specific problem, please create a new issue (you will need a GitHub account).

## Contributing

Finamp is a community-driven project and relies on people like **you** and their contributions. To learn how you could help out with making Finamp even better, take a look at our [Contribution Guidelines](CONTRIBUTING.md)

### Translations

You can also contribute by helping to translate Finamp! This is done through our Weblate instance here: <https://hosted.weblate.org/engage/finamp/>. The current translation status is this:

<a href="https://hosted.weblate.org/engage/finamp/">
  <img src="https://hosted.weblate.org/widget/finamp/finamp/horizontal-auto.svg" alt="Translation status" />
</a>

## Known Issues

This app is still a work in progress, and has some bugs/issues that haven't been fixed yet. Here is a list of currently known issues:

- Reordering the queue while shuffle is enabled is not possible at the moment. It seems like this is an issue with a dependency of Finamp (`just_audio`), and is being tracked [here](https://github.com/ryanheise/just_audio/issues/1042)
- If you have a very large library or an older phone, performance might not be great in some places

## Planned Features

- Improved Android Auto / Apple CarPlay support
- Full redesign, adding more features and a home screen. See [this issue](https://github.com/jmshrv/finamp/issues/220) for more info
- Better playlist editing
- Multiple users/servers
- More customization options

## Screenshots (Stable Version, outdated)

| | |
|:-------------------------:|:-------------------------:|
|![](https://raw.githubusercontent.com/jmshrv/finamp/master/fastlane/metadata/android/en-US/images/phoneScreenshots/1.png) | ![](https://raw.githubusercontent.com/jmshrv/finamp/master/fastlane/metadata/android/en-US/images/phoneScreenshots/2.png)
|![](https://raw.githubusercontent.com/jmshrv/finamp/master/fastlane/metadata/android/en-US/images/phoneScreenshots/3.png) | ![](https://raw.githubusercontent.com/jmshrv/finamp/master/fastlane/metadata/android/en-US/images/phoneScreenshots/4.png) |

Name source: <https://www.reddit.com/r/jellyfin/comments/hjxshn/jellyamp_crossplatform_desktop_music_player/fwqs5i0/>
