"""Experiment wave 3 (2026-11-02): looks and hook styles, from the X-likes review.

Tests what waves 1 and 2 hold constant:
  look   "night" (dusk to dark, cream serif, a glowing tree) and "plain" (lazy text on a flat
         colour, no art), against the "morning" look every earlier post uses.
  hook   "who you become" identity hooks (I) against topic hooks.
  app    posts with no app slide, the app named in the caption only (lazy slideshows with a
         subtle CTA beat hard app CTAs).

Voice rules are the same as posts.py: second person, the builder never tells a recovery story,
no alcohol on screen, no treat or cure claims, positive hooks (no "not X" framing), no em dashes.

Shape: hook, slides (list of "Kicker|text" lines), app (app slide line, or None), close.
Identity posts set trees: [(style, day), ...], one per slide, so the tree grows across the post.
"""

LOOKS = {"morning", "night", "plain"}

POSTS3 = [
    # ------------------------------------------------------------------ L: plain text (lazy)
    {"id": "L1", "look": "plain", "hook": "Small wins of your first alcohol-free month",
     "slides": ["Saturday mornings that start at 8, on purpose.",
                "Remembering how the movie ended.",
                "Opening your bank app without bracing.",
                "Texts from last night that you're happy to reread.",
                "A Sunday that feels twice as long."],
     "app": None, "close": "Which one surprised you most?",
     "caption": "Small wins add up fast. Save this for a day you need a reminder."},
    {"id": "L2", "look": "plain", "hook": "5 drinks to order at a bar when you're alcohol-free",
     "slides": ["Ginger beer with extra lime.", "Soda, cranberry and a squeeze of lime.",
                "Tonic with a grapefruit wedge.", "Iced tea with lemon, in a tall glass.",
                "Anything on the zero-proof menu. Ask, most bars have one now."],
     "app": None, "close": "What's your go-to order?",
     "caption": "Having your order ready makes the whole night easier."},
    {"id": "L3", "look": "plain", "hook": "Text this to a friend before the party",
     "slides": ['"I\'m taking a break from drinking. Can you have my back tonight?"',
                '"If I give you the look, help me make an exit by 10."',
                '"Grab me a soda and lime if you\'re at the bar?"',
                "Asking ahead turns one friend into your whole plan."],
     "app": None, "close": "Send it to the friend you'd pick.",
     "caption": "One text before you go makes the night so much lighter."},
    {"id": "L4", "look": "plain", "hook": "A Friday night plan for when you're alcohol-free",
     "slides": ["Late movie and the good popcorn.", "Cook the ambitious recipe you've been saving.",
                "Board games at your place, you pick the snacks.", "Hot tub, pool or a long night walk.",
                "Early bed, early hike, best Saturday in months."],
     "app": None, "close": "Pick one for this Friday.",
     "caption": "Friday nights can be your favourite night of the week again."},
    {"id": "L5", "look": "plain", "hook": "3 sentences to say to yourself on a hard day",
     "slides": ['"This feeling is real, and it will pass."',
                '"I only have to get through tonight."',
                '"Tomorrow morning, I\'ll be glad I did."',
                "Say them out loud. It works better than it sounds."],
     "app": "My app has a craving mode that walks you through the hardest 10 minutes.",
     "close": "Save this for the next hard day.",
     "caption": "Three lines to keep in your pocket."},

    # ------------------------------------------------------------------ Nt: night look
    {"id": "Nt1", "look": "night", "hook": "If it's 9pm and you want a drink, read this",
     "slides": ["Right now|Most urges rise, peak and fade in about 20 to 30 minutes.",
                "Set a timer|20 minutes. You only have to wait out the timer.",
                "While it runs|Something cold and fizzy. Brush your teeth. The day is done.",
                "When it rings|Notice the urge is smaller. That's you getting stronger."],
     "app": "My app has a craving mode that breathes with you through it.",
     "close": "Save this for 9pm.", "tree": ("pine", 120),
     "caption": "The 9pm urge has a timer."},
    {"id": "Nt2", "look": "night", "hook": "Sunday night, alcohol-free: a calm reset",
     "slides": ["7pm|Lay out tomorrow's clothes. One less decision.",
                "8pm|Something warm: tea, cocoa, a bath.",
                "9pm|Phone across the room. Book or show in bed.",
                "Monday|You wake up clear and a step ahead."],
     "app": None, "close": "Which step will you try tonight?", "tree": ("maple", 60),
     "caption": "A slower Sunday night makes for a lighter Monday."},
    {"id": "Nt3", "look": "night", "hook": "A bedtime routine for your first sober week",
     "slides": ["Same bedtime|Your body likes a rhythm. Pick a time and keep it all week.",
                "Warm drink|Chamomile, warm milk or decaf tea around 9.",
                "Screens down|Lights low for the last half hour.",
                "Be patient|Sleep often settles over the first couple of weeks."],
     "app": "My app grows a bonsai every night you stay alcohol-free.",
     "close": "Sleep well tonight.", "tree": ("sakura", 21),
     "caption": "Sleep can feel strange the first week. A routine helps."},
    {"id": "Nt4", "look": "night", "hook": "Read this if today was day 1 again",
     "slides": ["First|Starting again takes courage. You just did it.",
                "Your days still count|Every alcohol-free day you've had is still yours.",
                "Tonight|Eat something, drink water, go to bed early.",
                "Tomorrow|Day 2. That's the whole goal."],
     "app": "In my app, your tree keeps half its growth after a slip.",
     "close": "Day 2 starts when you wake up.", "tree": ("traditional", 2),
     "caption": "Day 1 again is still day 1. Proud of you."},

    # ------------------------------------------------------------------ I: who you become
    {"id": "I1", "look": "morning", "hook": "You on day 1 vs you on day 100 alcohol-free",
     "slides": ["Day 1|You count the hours.", "Day 10|You start to sleep through the night.",
                "Day 30|Mornings start to feel like yours.", "Day 100|You're the person with a plan."],
     "trees": [("traditional", 1), ("traditional", 10), ("traditional", 30), ("traditional", 100)],
     "app": "My app grows a bonsai with every sober day, so you can watch it happen.",
     "close": "What day are you on?",
     "caption": "Every day grows something. Where are you on the way to 100?"},
    {"id": "I2", "look": "night", "hook": "The quiet glow-up of a year alcohol-free",
     "slides": ["Month 1|You keep promises to yourself.", "Month 3|Weekends get longer.",
                "Month 6|People start asking what changed.", "Month 12|You barely remember the old Friday."],
     "trees": [("sakura", 30), ("sakura", 90), ("sakura", 180), ("sakura", 365)],
     "app": "My app grows a cherry blossom bonsai across your whole year.",
     "close": "Which month are you in?",
     "caption": "A year alcohol-free changes a lot of small things at once."},
    {"id": "I3", "look": "plain", "hook": "Who you become when you stop drinking",
     "slides": ["The friend who drives everyone home.", "The one who remembers the whole night.",
                "Up at 7 on a Saturday, and glad about it.", "Someone who keeps promises to yourself.",
                "Calmer, steadier and more yourself."],
     "app": None, "close": "Which one are you becoming?",
     "caption": "It's the small changes that add up to a new you."},
    {"id": "I4", "look": "morning", "hook": "Day 7, day 30 or day 300. Which one are you?",
     "slides": ["Day 7|The first week is behind you. That's huge.",
                "Day 30|A full month of mornings.",
                "Day 300|Proof you can do hard things."],
     "trees": [("maple", 7), ("maple", 30), ("maple", 300)],
     "app": "My app grows a Japanese maple with every sober day.",
     "close": "Tell me your day number.",
     "caption": "Every number is worth celebrating."},
]
