# Background Music Brief

This is a small, coherent first soundtrack pass for Fantasy Tactics. It
replaces the synthesized placeholder loops currently played by `AudioManager`;
it does not change music routing, crossfades, settings, or gameplay.

## Scope

Create three instrumental background-music loops:

| Game context | Runtime track id | Destination file | Role |
| --- | --- | --- | --- |
| Encampment | `music_encampment` | `assets/audio/music/music_encampment.wav` | A safe home base and recovery space. |
| World Map | `music_world_map` | `assets/audio/music/music_world_map.wav` | Purposeful travel and quiet anticipation. |
| Battlefield | `music_battle` | `assets/audio/music/music_battle.wav` | Focused tactical pressure without exhausting the player. |

The existing boss, victory, and defeat placeholders are intentionally outside
this pass.

## Shared musical direction

The three pieces should feel like one score, not three unrelated fantasy
tracks. Keep the palette rooted in intimate strings, wooden flutes, hand
percussion, low frame drums, and occasional restrained brass. Use a simple
four- or five-note modal motif, then vary its tempo, harmony, and orchestration
by context.

Avoid vocals, choirs, spoken words, famous melodies, named artists, trap beats,
and overly cinematic trailer hits. This is a thoughtful turn-based tactics game:
the music should leave room for planning, UI sounds, and combat feedback.

## AIVA generation workflow

1. Generate 8--12 candidates for each prompt. Keep the same seed/style when
   AIVA provides one, then make small controlled changes rather than changing
   every musical variable at once.
2. Shortlist by listening while playing the actual target screen. A track that
   sounds impressive alone can be tiring while a player reads, moves units, or
   waits between turns.
3. Export the selected version as a high-quality WAV. Edit it in a DAW or audio
   editor into a seamless loop: no hard attack at the loop point, no audible
   tail cutoff, and no long silence before the next cycle.
4. Replace only the matching destination filename above. `AudioManager` already
   loads those WAVs and crossfades when changing screens.

Suggested delivery target: a 75--110 second stereo WAV loop at 44.1 or 48 kHz.
Keep an unedited source export and record the final loop start/end points for
future revisions.

## Copy-ready AIVA prompts

### Encampment -- `music_encampment`

> Instrumental fantasy tactics game home-base music. A warm, intimate,
> restorative camp at dusk after an expedition: gentle fingerpicked lute,
> soft viola and cello, wooden flute, very light hand percussion, and a small
> four-note Dorian motif. Slow 72 BPM, calm and quietly hopeful, clear melody
> but plenty of breathing room for menus and dialogue. No vocals, choir,
> brass fanfare, trailer impacts, or dramatic ending. Compose a seamless
> 90-second loop with a soft, unobtrusive opening and a loop-friendly ending.

Evaluate variants for comfort over novelty. The loop should make the player
want to linger in the Encampment without becoming sleepy or sentimental.

### World Map -- `music_world_map`

> Instrumental fantasy tactics game exploration music. Rework the same
> four-note Dorian motif as a measured journey across a dangerous but hopeful
> frontier: pizzicato strings, wooden flute, light frame drum, subtle low
> strings, and occasional distant horn. Around 88 BPM, steady forward motion,
> adventurous and restrained rather than triumphant. No vocals, choir, modern
> drums, trailer impacts, or huge climax. Compose a seamless 100-second loop
> with clear travel rhythm and enough space for map interaction and UI sounds.

Evaluate variants for direction and momentum. It should invite one more move
on the World Map while preserving a hint that encounters can be dangerous.

### Battlefield -- `music_battle`

> Instrumental fantasy turn-based tactics battle music. Transform the same
> four-note Dorian motif into focused, contained conflict: low strings,
> staccato violas, muted horns, frame drums, sparse taiko-like accents, and
> a tense repeating ostinato. Around 108 BPM. Deliberate, alert, and tactical;
> energetic enough for combat but never frantic or wall-to-wall loud. No
> vocals, choir, electric guitars, EDM, trailer booms, or heroic final cadence.
> Compose a seamless 90-second loop with a quick understated opening and no
> resolved ending.

Evaluate variants for long-session fatigue. Battle turns can take time, so the
arrangement should cycle gently instead of demanding attention every bar.

## Selection and attribution record

For every retained candidate, keep a small local record containing the AIVA
account/plan, generation date, exact prompt and settings, downloaded source
filename, selected loop points, and final in-game filename. This makes a later
commercial release easy to audit without constraining this free release.

The game source may remain MIT-licensed, but do not claim that AIVA-generated
audio is itself MIT-licensed unless the applicable AIVA licence expressly
permits it. Ship the required AIVA credit with the final audio assets and keep
the exact licence/attribution wording captured when the tracks are downloaded.

## Acceptance check

Run `make play` and verify by ear:

- Encampment enters on the calm home-base loop.
- Deploying to the World Map crossfades to the exploration loop.
- Entering a normal battle crossfades to the tactical loop.
- Each loop can repeat at least twice without an audible gap, click, or abrupt
  musical restart.
- Music remains comfortably below UI and combat SFX at the default mixer level.
