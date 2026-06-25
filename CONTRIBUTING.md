# Contributing to Finamp

Thanks for your interest in contributing to Finamp! This document goes over how to get started on Finamp development, and other ways to contribute.

## Setting up a Development Environment

Finamp is a fairly standard Flutter app, so all you have to do is [install Flutter](https://docs.flutter.dev/get-started/install). Once Flutter is installed, you should be able to run Finamp on emulators/real devices.

### Android Keys

To build release APKs, you need to set up a signing key for Android. To get that set up, follow [this guide](https://docs.flutter.dev/deployment/android#signing-the-app) from the Flutter documentation. Note that if you have Finamp installed already, your phone may panic because the key is different.

### The Arcane Arts (Code Generation)

![A conversation between me and Chaphasilor. I say "did you try running (the Dart build command)?" They reply "I wasn't aware I need to use the arcane arts for this"](assets/arcane-arts.png)

Because Dart doesn't support macros and stuff, a few dependencies rely on code generation which must be run manually. These dependencies are:

* Hive - the database that Finamp uses for storing all data
* `json_serializable` - For deserialising JSON into classes
* Chopper - For talking to Jellyfin over HTTP
    * This layer (`lib/services/jellyfin_api.dart`) is not used by the app directly. The user-facing API is located at `lib/services/jellyfin_api_helper.dart`.

To rebuild these files, run `dart run build_runner build --delete-conflicting-outputs`. This must be done when:

* Modifying a class that is returned by Jellyfin (such as the classes in `lib/models/jellyfin_models.dart`)
* Adding fields to a database class (annotated with `@HiveType`)

If you don't rebuild generated files, you will encounter:

* Settings not persisting
* Hive errors on startup
* Missing data when converting JSON to classes

### Hive

As said earlier, Finamp uses Hive for all data storage needs. If you're doing work that involves data storage, I recommend you read [the Hive docs](https://docs.hivedb.dev/#/). Please ensure that your changes work when upgrading Finamp from the current release to your changes, as not handling upgrades will cause the app to crash. When downgrading, you will have to wipe your app data if any changes were made to Hive.

When creating new types, note that you'll also have to register an adapter in `main.dart`. After code generation, there should be a class called `[YourType]Adapter`, which you can initialise in `setupHive`.

## The Redesign

The biggest main piece of work being done on Finamp at the moment is the redesign. The relevant issue can be found [here](https://github.com/jmshrv/finamp/issues/220). The `redesign` branch has diverged a lot from `main`, but I try to keep it updated. If you're struggling to decide what to work on, the redesign is a good place to look :)

## Designing

As the name implies, we'll need many fresh design mockups for the redesign. Some are already done, some are still being interated on, and some mockups haven't been started yet.

If you are a designer or have ideas on how the new user interface could/should look, then it would be amazing and really helpfull if you would create a mockup!  
You can share your mockups in an issue here on GitHub (use a relevant one if possible, otherwise create a new one) or on Discord for further discussion.  
Once the mockup is finalized, people can start implementing it.

There's also a Figma file with some existing mockups that you can go off of: <https://www.figma.com/design/wVizekpm9YchvHFP6l508r/Finamp?node-id=101-425&t=27CRT9QAwFhlIMqm-1>  
Some of the designs in there are already outdated or still a work in progress. When in doubt, you should look at the current design in the actual app, or ask us about it!

## Translating

Finamp uses Weblate to manage translations: **https://hosted.weblate.org/engage/finamp/**

Feel free to add new languages if yours isn't there yet. If you have any questions, such as the context of a string, you can ask in the [Translation Discussions](https://github.com/jmshrv/finamp/discussions/categories/translations).

## Development Standards and AI / LLM Usage

1. **Design & Intent:** You should think about the problem you are trying to solve, and what approach you would like to take, before you start coding. Clearly verify and document the problem, the approach chosen, and the justification behind the chosen path. If unsure, discuss with the team.

2. **Verification:** After you have written the code (AI-assisted or not), you should verify the code works as expected. Screenshots and/or videos are good ways to share your test results.

3. **Ownership & Sustainability**: You are responsible for the code you write. Adding a new feature is a long-term commitment. We view contributors as the owners of the features they introduce. We want to keep the codebase healthy, so if a feature becomes unmaintainable, we may need to deprecate or remove it.

4. **AI usage:**

    4-1. **Disclosure & Responsibility:** If a PR was mostly generated by AI, you should include a statement in the PR comment on which tool / model you are using, and confirm that you are responsible for the code. This statement will be recorded in the merge commit message for documentation.

    4-2. **Attribution:** LLM co-authors should not be included in commits. Please remove them before submitting PRs. We want to ensure human contributors receive the credit.

    4-3. **Communications:** LLMs may be used for PR descriptions or comments where appropriate. However, you should be in charge of the PR, and should not be acting as an agent of the LLM. AI output should not be blindly echoed.

5. **Scope & Complexity:** PRs should be scoped and focused. If a PR starts getting too large or include changes across a wide area of code, we may ask you to split the PR into multiple smaller PRs.

6. **Code Quality:** Code quality requirements are judged on a case-by-case basis during review. Poor quality, low effort PRs may be closed without further explanation at the discretion of maintainers.
