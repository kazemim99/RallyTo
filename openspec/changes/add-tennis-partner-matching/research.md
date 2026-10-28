# Market Research: Partner-Finding Apps for Racket Sports

Researched 2026-10-23 from app-store listings, vendor help centres and third-party write-ups. Feature claims
come from public listings and were not verified hands-on.

## Comparable products

| Product | Where | Matching inputs | How a game is arranged | Ratings / trust | Business model |
|---|---|---|---|---|---|
| **Kort** (iOS) | Global | Self-entered experience level, location | Direct chat; **open invitations** for a place and time that others join; challenges with logged results | None described | Free + premium ($15.99/month, $39.99–49.99/year): unlimited discovery, change location, coach/hitting-partner profiles |
| **Spin** (iOS) | London, Sheffield, Oxford | Level (beginner / intermediate / advanced), proximity | **Post and join games**; availability tool on the Courts screen; friendly leagues by level with division chat; social events | Match scores and game history on profile; no player reviews described | Free |
| **Playtomic** | Europe, Middle East | Level 0–7 from an onboarding questionnaire, then adjusted after competitive matches, weighted by a **reliability** score | **Open matches** at partner clubs; level range auto-set from the first player (−0.25 / +0.75); players outside the range can ask and be accepted; friendly vs competitive matches | Players can report a no-show (no cancellation 24 h before); the absent player owes the court fee and is blocked until paid | Court booking commission; online payment to join |
| **Global Tennis Network** | Worldwide | Self-assigned level (often NTRP) | Partner finder, court finder (36,000+ courts), organiser-run leagues, ladders, tournaments | Ladder results | Yearly membership |
| **CourtBuds** (iOS) | US | Availability, proximity | Algorithmic partner suggestions from overlapping availability | Match logging | Free tier with messaging |
| **Jugá Tenis** (iOS) | Spanish-speaking markets | Location, level, **gender**, availability | Partner search with filters | Not described | Not described |
| **TennisPartner / TennisPAL** | US | Skill level, preferred days, distance | Match requests | Not described | Not described |
| **USTA Flex: Hitting Partner Program** | US | ITF World Tennis Number | Matches nearby players at the same level | Official rating | Federation programme |

No Iranian product doing partner matching turned up in Persian searches. Today Iranian players use club
contacts, coaches and messenger groups. Clubs such as Esteghlal Tennis Complex (Vanak, 14 courts) and Shahid
Pazouki (Darrous, 5 outdoor courts) do not appear to offer online booking.

## What Rallyto takes from them

| Observation | Where seen | Rallyto decision |
|---|---|---|
| A self-declared level is the norm at onboarding; only rating-backed products adjust it automatically | Kort, Spin, GTN vs Playtomic, USTA | Self-declared five-tier level plus experience duration per sport. Partners give post-match level-accuracy feedback, shown as a signal, not used to recompute the level (proposal) |
| An open invitation for a concrete time and place is the fastest way to a game | Kort, Spin, Playtomic | `play-posts` capability with open spots and host approval |
| Matching on overlapping availability, not just proximity | CourtBuds, Spin | `availability` + `partner-search` match on club + time-window overlap. Proximity is replaced by club, because player location is not collected |
| Gender is a common filter | Jugá Tenis | Gender filter in search and on posts, plus an optional same-gender visibility setting |
| No-shows are the main trust problem; Playtomic enforces with money | Playtomic | No payments in the MVP, so a reliability indicator from attendance confirmation and late cancellations, visible on the profile |
| Level ranges should be soft: out-of-range players can ask, the host decides | Playtomic | The post's level range is a filter and a hint; the host approves each join request |
| Singles vs doubles changes the arrangement (one partner vs several) | Spin, Playtomic (padel is 2v2) | Each sport defines its formats and players per side; posts carry open spots; doubles and padel matches get a group chat |
| None of the products documents blocking, reporting or verification | Kort, Spin | Trust and safety is a first-class capability: OTP-verified phones, block, report, moderation, message requests for first contact |
| Revenue comes from court booking, membership or premium discovery | Playtomic, GTN, Kort | Free MVP. Court booking (which would reuse AsanRezerve's booking and payment experience) and premium features are deliberately left for later |

## Iran-specific constraints found

- Distribution goes through Cafe Bazaar and Myket, as AsanRezerve's release process already does. Apple App
  Store publishing is not practical.
- Push notifications: Firebase Cloud Messaging works in production for AsanRezerve (confirmed by the product
  owner, 2026-10-23), so Rallyto uses FCM alone. The in-app notification center still stores every
  notification, so nothing depends on push being delivered.
- The Jalali calendar, Persian digits and RTL layout are required in every client.
- Sign-in uses the user's Iranian mobile number; no foreign identity provider is involved.

## Sources

- Kort, App Store: https://apps.apple.com/app/id1524701746
- Spin, App Store: https://apps.apple.com/app/id1399892510
- Playtomic level system: https://playerhelp.playtomic.com/hc/en-gb/articles/43310980754193-How-the-Playtomic-level-system-works
- Playtomic open matches (club configuration): https://helpmanager.playtomic.com/hc/en-gb/articles/20535035123473-How-to-configure-Open-Matches-at-your-Club
- Playtomic friendly vs competitive: https://help.playtomic.com/en/articles/5689294-friendly-vs-competitive-open-matches
- Playtomic no-shows: https://playerhelp.playtomic.com/hc/en-gb/articles/43240624037393-What-happens-if-a-player-doesn-t-show-up
- Jugá Tenis: https://mwm.ai/apps/jug-tenis/6756391352
- CourtBuds / partner-finder overview: https://mwm.ai/apps/courtmatch/6789594862
- Book & Go, finding a tennis partner: https://bookandgo.app/en/blog/find-tennis-partner
- Global Tennis Network: https://gust.com/companies/global-tennis-network
- USTA Connect / WTN: https://www.usta.com/en/home/about-usta/usta-connect.html
- Esteghlal Tennis Complex: https://fa.wikifeqh.ir/مجموعه_ورزشی_تنیس_استقلال_(تهران)
- Shahid Pazouki Tennis Club: https://fa.wikifeqh.ir/باشگاه_تنیس_شهید_پازوکی_تهران
- .NET 8/9 end of support: https://devblogs.microsoft.com/dotnet/dotnet-8-9-end-of-support/
