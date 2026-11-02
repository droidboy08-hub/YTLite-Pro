# YTLite Pro

A flexible enhancer for YouTube on iOS, with more than a hundred options.

In the app it shows up as **YouTube Plus**, a row in YouTube's Settings. This release gives that feature for free rather than gatekeeping it, so anyone can use it.

YTLite Pro is a standalone copy of [dayanch96/YTLite](https://github.com/dayanch96/YTLite). It adds a downloader, a layered ad blocker, and SponsorBlock. Upstream changes are merged in by hand, so they can't overwrite these additions. The **Create YouTube Plus app** and **Cyan/TrollFools** workflows build this repository, and YouTube Plus in that build is free for anyone.

## YouTube Plus in Settings

Open **YouTube → Settings → YouTube Plus**. Downloads, ad blocking, SponsorBlock, and the other options are all on that screen. Anyone who installs a build from this repository can use them.

## How to build a YouTube Plus app using Github actions

Build your own app with these tweaks.

Before the first run:

1. Fork this repository.
2. On the fork, open **Settings → Actions → General** and set workflow permissions to **Read and write**.

### Create YouTube Plus app

1. Open the **Actions** tab and choose **Create YouTube Plus app**.
2. Click **Run workflow**.
3. Turn on any extra tweaks you want. Details are in [Tweak integration](#tweak-integration).
4. Put a direct download link to a decrypted YouTube `.ipa` in **URL to the decrypted IPA file**. This repository does not include the YouTube app. A link to a webpage will fail; it has to be the file itself.
5. Change the app name or bundle ID if you want to. **Build on Linux** is faster when Mac runners are busy.
6. Click **Run workflow** and wait for it to finish.
7. Download the app from the **Releases** page of your fork. Add `/releases` to the repository URL if you don't see that page. The file is a draft named `YouTubePlus vytlite-source`.

### Cyan and TrollFools

**Actions → Generate TrollFools/Cyan files** builds the same free YouTube Plus tweaks and uploads a `.cyan` file and a TrollFools `.zip`.

### Beta

**[BETA] Create YouTube Plus app** is for a tweak package you already have. Paste that package's direct link in **URL to the YouTube Plus tweak file**. For the free YouTube Plus from this repository, use **Create YouTube Plus app**.

## What this repository adds

- **Downloader.** Saves video or audio on the device. Notes on formats and the Files app are in [docs/Research.md](docs/Research.md).
- **Ad blocker.** A layered blocker for video ads, feed ads, Shorts ads, and shopping placements. The switch is in YouTube Plus settings.
- **SponsorBlock.** Skips sponsor segments using the public SponsorBlock list.

## Tweak integration

These are optional. Leave them off and the build still includes YouTube Plus from this repository.

<details>
  <summary>YouPiP</summary>
  <p>Picture in Picture for videos in the YouTube app, by <a href="https://github.com/PoomSmart/YouPiP">PoomSmart</a>. Its settings appear in YouTube's Settings.</p>
</details>

<details>
  <summary>YTUHD</summary>
  <p>Higher resolutions in the YouTube app, including 1440p and 2160p where the device supports them, by <a href="https://github.com/PoomSmart/YTUHD">PoomSmart</a>. Quality choices are under video quality in YouTube's Settings.</p>
</details>

<details>
  <summary>YouQuality</summary>
  <p>Change quality from the video overlay, by <a href="https://github.com/PoomSmart/YouQuality">PoomSmart</a>. Turn it on from the video overlay section in YouTube's Settings.</p>
</details>

<details>
  <summary>Return YouTube Dislikes</summary>
  <p>Shows dislike counts again, by <a href="https://github.com/PoomSmart/Return-YouTube-Dislikes">PoomSmart</a>. Its settings appear in YouTube's Settings.</p>
</details>

<details>
  <summary>YTABConfig</summary>
  <p>Extra controls for the YouTube A/B configuration, by <a href="https://github.com/PoomSmart/YTABConfig">PoomSmart</a>.</p>
</details>

<details>
  <summary>DontEatMyContent</summary>
  <p>Keeps the notch and Dynamic Island from covering 2:1 video, by <a href="https://github.com/therealFoxster/DontEatMyContent">therealFoxster</a>. Its settings appear in YouTube's Settings.</p>
</details>
