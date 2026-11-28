-- The natives' dialogue tree (dialogue spec). start: the first node for each attitude. A node: text (with %s for the
-- faction's name) and options {text, go = next node or nil (the talk ends), effect = a dialogue.EFFECTS name,
-- needs = the least attitude to offer it}. Mods add trees with dialogue.register.
return {
  start = { hostile = "warning", territorial = "challenge", fearful = "afraid", curious = "welcome", trading = "welcome" },
  nodes = {
    warning = { text = "The %s raise their spears. 'Leave our land, metal giant.'", options = {
      { "Leave in peace.", effect = "respect" },
      { "Offer a gift.", go = "gift", effect = "gift" },
      { "Stand your ground.", effect = "insult" },
    } },
    challenge = { text = "'You walk on %s land, star-walker. Why?'", options = {
      { "I come in peace.", go = "peace", effect = "respect" },
      { "Offer a gift.", go = "gift", effect = "gift" },
      { "That is none of your business.", effect = "insult" },
    } },
    afraid = { text = "The %s back away from the suit, whispering.", options = {
      { "Show your open hands.", go = "peace", effect = "respect" },
      { "Walk on.", },
    } },
    welcome = { text = "'Star-walker! The %s greet you. What do you seek?'", options = {
      { "Ask about the old ruins.", go = "ruins", effect = "reveal_ruin" },
      { "Ask about the thieves.", go = "thieves", effect = "reveal_hideout" },
      { "Goodbye.", },
    } },
    peace = { text = "'Then walk softly among the %s.'", options = {
      { "Ask about the old ruins.", go = "ruins", effect = "reveal_ruin", needs = "curious" },
      { "Goodbye.", },
    } },
    gift = { text = "'A gift... the %s will remember this.'", options = { { "Goodbye.", } } },
    ruins = { text = "'The old ones' stones stand where the sky-fire fell. Wake the pillars by their marks, the fewest first.'",
      options = { { "Thank you.", } } },
    thieves = { text = "'The takers live far from here. They steal what is left alone.'", options = { { "Thank you.", } } },
  },
}
