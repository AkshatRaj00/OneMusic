# 🎵 OneMusic

<p align="center">
  <img src="https://img.shields.io/badge/OneMusic-Open%20Source-FF2D55?style=for-the-badge"/>
  <img src="https://img.shields.io/badge/Flutter-Dart-02569B?style=for-the-badge&logo=flutter"/>
  <img src="https://img.shields.io/badge/Ad--Free-Yes-00C853?style=for-the-badge"/>
  <img src="https://img.shields.io/badge/License-MIT-black?style=for-the-badge"/>
</p>

<p align="center">
  <strong>Free • Open Source • Ad-Free Music Streaming</strong><br/>
  A clean, fast and distraction-free music experience by <b>OnePersonAI</b>.
</p>

<p align="center">
  🎧 Stream &nbsp;•&nbsp; 🔎 Discover &nbsp;•&nbsp; ❤️ Like &nbsp;•&nbsp; ⚡ Play &nbsp;•&nbsp; 📱 Listen
</p>

---

## 🎬 Demo

<p align="center">

<a href="YOUR_VIDEO_LINK">
  <img src="https://img.shields.io/badge/▶%20Watch%20OneMusic%20Demo-E53935?style=for-the-badge"/>
</a>

</p>

<p align="center">
  <img src="https://github.com/user-attachments/assets/df50fa1c-ed52-4195-8fb0-764899687bed" width="90%">
</p>

---

## ✨ Features

```text id="f1"
🎧 Smart Autoplay
🔥 Infinite Music Queue
🌙 Premium Dark UI
❤️ Liked Songs
🕘 Recently Played
🔍 Fast Search
📱 Responsive Experience
🆓 Completely Free
🌍 Open Source
⚡ Lightweight & Fast
```

---

## 🔄 OneMusic Flow

```mermaid id="j3p8z2"
flowchart LR
    A[👤 User] --> B[🎵 OneMusic]

    B --> C[🔎 Search]
    B --> D[❤️ Library]
    B --> E[🕘 History]

    C --> F[🌐 Music Sources]
    F --> G{Track Found?}

    G -->|Yes| H[▶️ Audio Stream]
    G -->|No| I[🔄 Next Source]

    I --> F

    H --> J[🎧 Player]
    J --> K[🔥 Queue]
    J --> L[📱 Background Playback]

    D --> J
    E --> J
```

---

## 🏗️ Architecture

```text id="q0t4f6"
                    ┌──────────────────┐
                    │     OneMusic     │
                    └────────┬─────────┘
                             │
             ┌───────────────┼────────────────┐
             ▼               ▼                ▼
         Search UI       Music Engine      Library
             │               │                │
             ▼               ▼                ▼
        Music Sources    Audio Player      Favorites
                             │
                  ┌──────────┼──────────┐
                  ▼          ▼          ▼
               Queue     Background   History
                  │          Audio        │
                  └──────────┼───────────┘
                             ▼
                       🎧 User Experience
```

---

## 🧠 Core Experience

```text id="y4d1x9"
Search
  ↓
Find Track
  ↓
Resolve Stream
  ↓
Play Audio
  ↓
Queue / Autoplay
  ↓
Background Playback
  ↓
History + Favorites
```

---

## 🛠️ Tech Stack

| Layer | Technology |
|---|---|
| Mobile App | **Flutter / Dart** |
| Android | **Kotlin + Gradle** |
| Music Sources | **JioSaavn / YouTube** |
| Audio | **Streaming Engine** |
| UI | **Modern Dark UI** |
| Website | **Web + Vercel** |
| Releases | **GitHub Releases** |

---

## 📱 Screenshots

<p align="center">
  <img src="assets/screenshot-1.png" width="210"/>
  <img src="assets/screenshot-2.png" width="210"/>
  <img src="assets/screenshot-3.png" width="210"/>
  <img src="assets/screenshot-4.png" width="210"/>
</p>

---

## 🌐 Official Website

<p align="center">

<a href="https://onemusic-website.vercel.app/">
  <img src="https://img.shields.io/badge/🌐%20Visit%20OneMusic%20Website-FF2D55?style=for-the-badge"/>
</a>

</p>

---

## 📥 Download

<p align="center">

<a href="https://github.com/AkshatRaj00/OneMusic/releases/tag/main">
  <img src="https://img.shields.io/badge/📱%20Download%20APK-GitHub%20Releases-black?style=for-the-badge"/>
</a>

</p>

---

## 🎯 Why OneMusic?

```text id="5w2a9e"
Traditional Music Apps
        ↓
Ads
Subscriptions
Login Walls
Distractions
        ↓
      OneMusic
        ↓
Music First 🎧
```

> **Music experience first.**

---

## 🚀 Vision

OneMusic is built under the **OnePersonAI** ecosystem with a simple vision:

```text id="2x4m7c"
Clean Design
     +
Open Technology
     +
Free Music Experience
     =
      OneMusic 🎵
```

---

## 🤝 Contributing

```text
Fork
 ↓
Improve
 ↓
Test
 ↓
Pull Request
 ↓
OneMusic ❤️
```

Bug reports, UI improvements, performance optimizations and new features are welcome.

---

<p align="center">

### 🎵 OneMusic

<strong>Music without the noise.</strong>

<br/>

Built with ❤️ by <b>OnePersonAI</b>

<br/><br/>

⭐ <b>Star the repository if you like it.</b>

</p>
