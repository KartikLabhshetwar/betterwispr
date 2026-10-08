export const REVIEWED_ON = "October 8, 2026";

export const BETTERWISPR_FACTS = [
  ["Platform", "macOS 14 or later; Apple Silicon recommended"],
  ["Speech processing", "On your Mac, with no cloud transcription fallback"],
  ["Offline use", "After explicitly installing a compatible local model"],
  ["Account", "No account or API key required in the app"],
  ["Price model", "Free; no dictation subscription"],
  [
    "Text cleanup",
    "Local cleanup levels, per app styles, vocabulary and learned corrections",
  ],
] as const;

export interface Comparison {
  slug: string;
  name: string;
  category: string;
  summary: string;
  intro: string;
  facts: [string, string, string, string, string, string];
  betterFor: string;
  alternativeFor: string;
  takeaway: string;
  sources: { label: string; url: string }[];
}

export const comparisons: Comparison[] = [
  {
    slug: "superwhisper",
    name: "Superwhisper",
    category: "Local + cloud",
    summary: "Local models, cloud options and configurable writing modes.",
    intro:
      "Both apps can transcribe locally. The choice is about how much control you want over models and writing workflows.",
    facts: [
      "Mac, Windows, iOS and Android; capabilities vary by platform",
      "Local and cloud models; depends on your selection",
      "Available with local models on supported hardware",
      "No account required for the free offline workflow",
      "Free tier; subscription and lifetime Pro options",
      "Custom prompts, writing modes, and local or cloud AI models",
    ],
    betterFor:
      "You want a focused Mac dictation workflow with local transcription, simple cleanup and no cloud provider to configure.",
    alternativeFor:
      "You want configurable writing modes, optional cloud models or support beyond macOS. Superwhisper has a free tier and paid Pro plans.",
    takeaway:
      "Offline is not a unique BetterWispr advantage here. Compare the workflow, available models and how much text rewriting you actually want.",
    sources: [
      {
        label: "Superwhisper features and plans",
        url: "https://superwhisper.com/",
      },
      {
        label: "Superwhisper local models and changelog",
        url: "https://superwhisper.com/changelog",
      },
      {
        label: "Superwhisper offline and account requirements",
        url: "https://ai.superwhisper.com/offline-transcription",
      },
    ],
  },
  {
    slug: "wispr-flow",
    name: "Wispr Flow",
    category: "Cloud dictation",
    summary: "Polished writing across devices, with cloud processing.",
    intro:
      "BetterWispr keeps speech recognition on your Mac. Wispr Flow focuses on polished dictation across desktop and mobile, with an internet connection.",
    facts: [
      "Mac, Windows, iOS and Android",
      "Cloud transcription",
      "An internet connection is required to start dictation",
      "Account with free and paid plans",
      "Free tier with usage limits; paid subscriptions",
      "Automatic editing, contextual formatting and a custom dictionary",
    ],
    betterFor:
      "You need to dictate without sending recordings to a speech service, including when your Mac is offline after model setup.",
    alternativeFor:
      "You want one dictation service across computers and phones, automatic writing polish or team administration. Check the free plan limits and paid plans.",
    takeaway:
      "Start with your connectivity and processing requirements. Cloud processing and data retention are separate questions; review Flow’s current privacy settings as well.",
    sources: [
      { label: "Wispr Flow features", url: "https://wisprflow.ai/" },
      {
        label: "Starting a dictation and connectivity",
        url: "https://docs.wisprflow.ai/articles/6409258247-starting-your-first-dictation",
      },
      { label: "Wispr Flow plans", url: "https://wisprflow.ai/pricing" },
    ],
  },
  {
    slug: "kivi",
    name: "Kivi by Sarvam",
    category: "Indian language workflows",
    summary:
      "Multilingual dictation, remembered corrections and voice editing.",
    intro:
      "Kivi is Sarvam’s Mac voice app, sometimes searched for as Kiwi. It emphasizes Indian languages and editing by voice. BetterWispr emphasizes local speech recognition.",
    facts: [
      "Mac; macOS 14 or later advertised",
      "The reviewed product pages do not establish a fully local audio path",
      "Not confirmed by the reviewed official documentation",
      "Required, according to Kivi’s privacy policy",
      "Free during alpha; future pricing may change",
      "Remembered corrections, app personas, drafting and voice editing",
    ],
    betterFor:
      "Your priority is a documented local transcription path with no account. Choose a model that supports your language and test it with your own speech.",
    alternativeFor:
      "You regularly mix English and Indian languages, or want to draft and edit with spoken instructions. Kivi advertises 22+ Indian languages and is free during alpha.",
    takeaway:
      "Kivi’s language focus may be a better fit for multilingual Indian workflows. Its public pages do not confirm offline operation, so verify that requirement directly before choosing.",
    sources: [
      {
        label: "Kivi product and alpha availability",
        url: "https://heykivi.ai/",
      },
      { label: "Kivi languages and modes", url: "https://heykivi.ai/faq.html" },
      {
        label: "Kivi account and privacy policy",
        url: "https://heykivi.ai/privacy.html",
      },
    ],
  },
  {
    slug: "fluidvoice",
    name: "FluidVoice",
    category: "Local + optional cloud AI",
    summary: "Local speech recognition with optional AI writing enhancement.",
    intro:
      "Both apps offer local dictation on Mac. FluidVoice adds a broader writing toolkit, including its Fluid Intelligence enhancement model.",
    facts: [
      "macOS 15 or later; Apple Silicon and Intel paths",
      "Local speech models; optional local or cloud text enhancement",
      "Available with local speech and enhancement models installed",
      "Free and open source; optional external AI services have their own requirements",
      "Free and open source; optional external services may charge",
      "Fluid Intelligence, app prompts, Write Mode and Command Mode",
    ],
    betterFor:
      "You use macOS 14 or prefer a smaller dictation workflow built around vocabulary, explicit replacements and local transcript history.",
    alternativeFor:
      "You want richer writing modes and local AI rewriting, and your Mac meets FluidVoice’s requirements. FluidVoice is also free, so price alone does not distinguish these workflows.",
    takeaway:
      "Both support local speech processing. With FluidVoice, check which enhancement provider you enable; optional cloud text processing changes where your transcript goes.",
    sources: [
      {
        label: "FluidVoice official product page",
        url: "https://altic.dev/fluid",
      },
      {
        label: "FluidVoice source and requirements",
        url: "https://github.com/altic-dev/FluidVoice",
      },
      {
        label: "FluidVoice privacy and optional providers",
        url: "https://altic.dev/fluid/privacy-policy",
      },
    ],
  },
  {
    slug: "macwhisper",
    name: "MacWhisper",
    category: "Dictation + transcription",
    summary: "A transcription workspace for files, subtitles and dictation.",
    intro:
      "MacWhisper combines dictation with tools for working through recorded media. BetterWispr’s dictation flow centers on speaking into the app you already have open.",
    facts: [
      "Mac; a separate iOS and iPad app is also available",
      "Local models, with optional external AI integrations",
      "Local transcription is available with downloaded models",
      "Free edition and a paid Pro license; optional services have separate terms",
      "Free edition; Pro sold as a one time license",
      "AI prompts, grammar improvement and local or external AI integrations",
    ],
    betterFor:
      "You mainly dictate messages, notes and prompts into existing apps, with local recognition and a vocabulary you control.",
    alternativeFor:
      "You need batch file transcription, subtitle exports, speaker recognition or a workspace for reviewing recordings. Feature availability varies between Free and Pro.",
    takeaway:
      "Compare the job you do most often. A media transcription workspace and a shortcut you use throughout the day solve overlapping but different needs.",
    sources: [
      {
        label: "MacWhisper features, platforms and plans",
        url: "https://www.macwhisper.com/",
      },
      {
        label: "MacWhisper documentation",
        url: "https://docs.macwhisper.com/",
      },
    ],
  },
  {
    slug: "aqua-voice",
    name: "Aqua Voice",
    category: "Contextual dictation",
    summary: "Dictation with context and specialized vocabulary support.",
    intro:
      "Aqua Voice focuses on contextual dictation for Mac and Windows. BetterWispr offers a Mac workflow with an explicitly local speech processing path.",
    facts: [
      "Mac and Windows",
      "Cloud dictation is offered; check the selected mode",
      "Official FAQ says availability varies by platform, version and mode",
      "Starter allowance and paid plans",
      "Starter word allowance; paid plans",
      "Contextual dictation and custom vocabulary",
    ],
    betterFor:
      "You want local transcription as a fixed requirement, without depending on a service connection or configuring a cloud account.",
    alternativeFor:
      "You want contextual dictation across Mac and Windows and are comfortable checking the processing and plan details for your setup.",
    takeaway:
      "Do not assume all Aqua modes have the same offline behavior. Its own FAQ recommends checking support for your platform, app version and mode.",
    sources: [
      { label: "Aqua Voice product and plans", url: "https://aquavoice.com/" },
      {
        label: "Aqua Voice connectivity and free allowance",
        url: "https://aquavoice.com/info/faq",
      },
    ],
  },
  {
    slug: "apple-dictation",
    name: "Apple Dictation",
    category: "Built into macOS",
    summary: "The built in option, with no extra dictation app to install.",
    intro:
      "Apple Dictation is a sensible starting point for occasional voice typing. BetterWispr adds selectable speech models, vocabulary replacements and local transcript history.",
    facts: [
      "Built into macOS",
      "On device or server dependent; check Keyboard settings",
      "Depends on your Mac, language and settings",
      "No separate dictation subscription",
      "Included with macOS",
      "Punctuation and formatting commands; features vary by language",
    ],
    betterFor:
      "You want to select between Apple speech, Parakeet and Whisper, keep raw and corrected transcripts, or define repeatable phrase replacements.",
    alternativeFor:
      "You only need occasional dictation and the built in option works well for your language. Start in System Settings → Keyboard → Dictation.",
    takeaway:
      "Try the built in option first if it meets your needs. Apple’s Keyboard settings tell you whether your configuration requires internet or processes general dictation on your device.",
    sources: [
      {
        label: "Apple’s Mac Dictation guide",
        url: "https://support.apple.com/guide/mac-help/mh40584/mac",
      },
    ],
  },
];
