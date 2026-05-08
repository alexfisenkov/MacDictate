# Text Improvement Editor Profile Design

## Context

MacDictate 1.5.0 has an optional second local model: Qwen2.5-1.5B-Instruct Q4_K_M through `llama.cpp`. The first implementation proved the local pipeline works, but the model needed stronger editorial behavior: preserve meaning, fix errors, know common domain terms, and format dictated text into paragraphs or lists when the input implies structure.

This is not a true model fine-tune. The fast, testable step is a deterministic editor profile: prompt rules, compact terminology packs, speech-normalization hints, and regression harness coverage.

## Decision

Add `TextImprovementProfile` as the source of truth for Qwen prompt construction. `TextImprovementRunner` receives a profile, defaults to `.professionalCopyEditor`, and writes the profile-built prompt to the llama.cpp prompt file.

The profile contains:

- strict editing rules: fix spelling, punctuation, capitalization, obvious ASR errors, but do not change meaning;
- formatting rules: paragraphs, bullet lists for unordered enumerations, numbered lists for ordered steps;
- terminology packs for AI/ML, finance/accounting/business, medicine, content/video/design, software/product/cloud, and marketing/creator business;
- speech-normalization hints for common dictated variants such as ChatGPT, OpenAI, Qwen, DaVinci Resolve, Final Cut Pro, Adobe Premiere Pro, CapCut, Figma, Midjourney, EBITDA, and HbA1c.

Add a narrow deterministic formatter after model output. It only handles obvious cases where Qwen remains too conservative:

- common dictated terminology replacements such as `чат джпт -> ChatGPT`, `давинчи резолв -> DaVinci Resolve`, `ebitda -> EBITDA`, `контент план -> контент-план`;
- obvious ordered enumerations using speech markers such as `во первых`, `во вторых`, `в третьих`.

## Boundaries

The profile is a local prompt layer only. It must not:

- add facts, legal/medical/financial advice, disclaimers, or commentary;
- translate proper names unless the original text already implies that;
- block base dictation if Qwen or `llama.cpp` fails;
- claim exhaustive terminology knowledge.

## Verification

`scripts/test_text_improvement_runner.sh` checks that the generated prompt includes the source text, no-meaning-change rule, list-formatting rules, and representative terms from AI, finance, medicine, and creator/video domains. The existing runner tests still cover timeout, stderr/stdout drain, missing runtime/model, safe input limit, and non-zero failures.

The same harness checks deterministic formatter behavior for ordered list markers and common terminology fallback. A real local Qwen smoke should still be run when changing profile wording because small local models can become too conservative with long prompts.

Runtime quality must still be improved with real dictated examples over time. Those examples can later become an evaluation corpus or a true fine-tuning dataset.
