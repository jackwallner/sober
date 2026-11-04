"""The hooks-v3 posts. `clip` is the Pexels id the footage file name starts with (rain's file uses its own id)."""

from __future__ import annotations

HALLWAY = "5203510"
SILHOUETTE = "8862328"
RAIN = "14904126"

TAGS = {
    "secrets": "#sobercurious #quitdrinking #greyareadrinking",
    "people": "#sobercurious #quitdrinking #alcoholfree",
    "morning": "#hangxiety #quitdrinking #sobercurious",
    "bargaining": "#sobertok #quitdrinking #greyareadrinking",
    "cost": "#sobertok #quitdrinking #sobercurious",
    "topical": "#sobertok #sobercurious #holidays",
}


def post(num: int, family: str, clip: str, first: str, second: str, caption: str, heavy: bool = False, **kw) -> dict:
    return {"id": f"H{num:02d}", "family": family, "clip": clip, "beats": [first, second],
            "caption": caption, "heavy": heavy, "tags": TAGS[family], **kw}


POSTS = [
    post(1, "secrets", HALLWAY, "You told your doctor 2 drinks a night.", "What's the real number?",
         "Your doctor has heard every number there is. Say the real one out loud, even just to yourself.", True),
    post(2, "secrets", "7822022", "You've googled \"am I drinking too much\" more than once.", "You already know why you keep asking.",
         "Nobody googles that about something they feel fine about."),
    post(3, "secrets", "35621441", "You bought the wine at a different store this time.", "You know exactly why.",
         "Who were you worried would notice?"),
    post(4, "secrets", "32535226", "You take the empties out when nobody's home.", "Who are you hiding them from?",
         "Hiding it takes a lot out of you. You're allowed to be done."),
    post(5, "secrets", "7924514", "You keep a count of your drinks so nobody else can.", "That's a lot of work for something you're fine with.",
         "Think about how much of your day goes to managing this."),
    post(6, "secrets", "7686952", "You topped the vodka up with water so nobody would notice.", "You're tired. You can stop doing this.",
         "All that effort could go somewhere else.", True),
    post(7, "people", SILHOUETTE, "Somebody in your house counts your drinks too.", "They just stopped saying it out loud.",
         "What would they say if you asked?", True),
    post(8, "people", "8862322", "Your kids know what your voice sounds like after the second glass.", "They'd love to hear the other one at bedtime.",
         "They notice more than you think. Tonight can go differently."),
    post(9, "people", "40481366", "Your partner goes to bed before you open the second bottle now.", "Have you asked why?",
         "A hard question. It might be a good conversation."),
    post(10, "people", "7270300", "Your friends plan around how you get after three drinks.", "You could give them a different night.",
         "Who's been quietly managing you?"),
    post(11, "people", "31252867", "Your mom asked how much you've been drinking lately.", "She practiced that question for months.",
         "That question was love. You can answer it honestly."),
    post(12, "morning", "7822022", "You read your texts to find out how drunk you got.", "You could wake up already knowing.",
         "Imagine opening your phone tomorrow with nothing to check.", start=2.0, flip=True),
    post(13, "morning", "30039319", "3 AM. Heart pounding. Last night's wine wearing off.", "You could sleep through tonight.",
         "Many people find they sleep better once alcohol is out of the evening.", True),
    post(14, "morning", "8860236", "You remember the fight. Six drinks in, you can't remember what you said.", "They can.",
         "They're still carrying it. You can start repairing that today.", True),
    post(15, "morning", "17041569", "You apologized this morning for something you said drunk.", "You could have a morning with nothing to fix.",
         "Picture that morning."),
    post(16, "morning", "31470192", "You're extra nice the morning after drinking. Everyone in your house knows why.", "You could have a morning with nothing to make up for.",
         "They'd take you on any morning. Just all of you."),
    post(17, "bargaining", RAIN, "You're waiting for your drinking to get bad enough.", "You're allowed to stop before that.",
         "There's no line you have to cross first. Today can be Day 1.", True),
    post(18, "bargaining", "35099181", "\"I'll take this week off drinking.\" How many Mondays is that now?", "Today could be the one that sticks.",
         "You don't need a Monday. Any day works.", True),
    post(19, "bargaining", "7270299", "You made a rule. Only drink on weekends. Then Thursday became a weekend.", "You know where this goes. You can get off here.",
         "What was the first rule you made? What happened to it?"),
    post(20, "bargaining", "6722763", "You've stopped saying \"just one drink.\" Now you skip that part.", "You still get to decide about tonight.",
         "One evening at a time is plenty."),
    post(21, "bargaining", SILHOUETTE, "You've gotten really good at seeming sober.", "What would it feel like to stop working so hard?",
         "That performance takes everything you've got.", start=14.0),
    post(22, "bargaining", SILHOUETTE, "Everyone thinks your drinking's under control. You're very good at that.", "You can put that down.",
         "You don't have to hit bottom to be tired of holding this up.", start=27.0, flip=True),
    post(23, "bargaining", RAIN, "You've already decided you're drinking tonight. It's 2 PM.", "You've got hours to change your mind.",
         "Plan the first hour of tonight now, while it's easy.", True, flip=True),
    post(24, "cost", "17041569", "You can't remember the last Sunday you didn't wake up hungover.", "That one can be next Sunday.",
         "Think about what you'd do with a whole Sunday.", start=5.0, flip=True),
    post(25, "cost", "15019286", "You were there. The drinks erased the end of it.", "You could keep the whole night.",
         "How many nights have you lost the end of?", True),
    post(26, "cost", "39105124", "When did every plan start needing a drink in it?", "Try one plan without it this week.",
         "Pick the easy one. A walk, a coffee, a movie."),
    post(27, "cost", "39218436", "Picture one more year of drinking exactly like this.", "How does that feel?",
         "That feeling is worth listening to.", True),
    post(28, "topical", "39105124", "Thanksgiving's coming. You're already planning how much wine you can get away with.", "You could go and remember all of it.",
         "Bring your own drink and have your exit planned. You can leave whenever you want.", start=3.0, flip=True),
    post(29, "topical", "6016323", "Sober October's over. You counted down to that first drink, didn't you?", "Day 1 can still be today.",
         "You did a whole month. You know more than you did.", True),
    post(30, "topical", "7270299", "Holiday party's coming. You're already nervous about who shows up after three drinks.", "You could walk out as the person who walked in.",
         "Have your drink order picked before you get there.", start=2.0, flip=True),
]
