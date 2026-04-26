# Voice Ledger AI

This document defines the cloud voice-bookkeeping contract used by the AI Billing voice tab.

The voice flow is intentionally separate from screenshot Auto Ledger:

- screenshot / OCR parsing uses `AUTO_LEDGER_OPENAI_*`
- voice bookkeeping uses `VOICE_LEDGER_AI_*`

Both flows return the same `AutoLedgerParseEnvelope` shape so they can share review and save logic.

## Environment keys

Use the variables from `.env.template`:

- `VOICE_LEDGER_AI_ENDPOINT`
- `VOICE_LEDGER_AI_API_KEY`
- `VOICE_LEDGER_AI_MODEL`
- `VOICE_LEDGER_AI_ENABLE_THINKING`
- `VOICE_LEDGER_AI_SYSTEM_PROMPT`
- `VOICE_LEDGER_AI_USER_PROMPT_TEMPLATE`

On iOS, the app reads these values from:

1. Xcode Scheme environment variables
2. `mobile_project/Info.plist`

It does not read `.env` directly at runtime.

## Call sites

The voice model configuration lives in `mobile_project/ViewModels/AutoLedgerLLM.swift`.

The network client lives in `mobile_project/ViewModels/AutoLedgerFlow.swift`:

- `VoiceLedgerGatewayService.parseVoice(...)`

The voice UI and fallback orchestration live in `mobile_project/Views/ManagementViews.swift`:

- `VoiceRecognitionViewModel`
- `AIBillingView`

## Request contract

The app records microphone input locally, writes it to a temporary WAV file, then uploads the complete audio after the user stops speaking or recording ends.

The remote request is OpenAI-compatible and uses multipart user content:

```json
{
  "model": "Qwen/Qwen3-Omni-30B-A3B-Instruct",
  "messages": [
    {
      "role": "system",
      "content": "..."
    },
    {
      "role": "user",
      "content": [
        {
          "type": "input_audio",
          "input_audio": {
            "data": "data:;base64,...",
            "format": "wav"
          }
        },
        {
          "type": "text",
          "text": "..."
        }
      ]
    }
  ],
  "stream": true,
  "stream_options": { "include_usage": true },
  "modalities": ["text"],
  "extra_body": { "enable_thinking": false }
}
```

Notes:

- the audio payload is sent as Base64 with a `data:;base64,` prefix
- the concrete format is sent separately in `input_audio.format`
- the current implementation expects streamed text chunks and assembles them into a final JSON string
- this path is designed to work with providers that expose OpenAI-compatible chat-completions audio input

## Prompt placeholders

`VOICE_LEDGER_AI_USER_PROMPT_TEMPLATE` supports:

- `{{currencyCode}}`
- `{{localeIdentifier}}`
- `{{categoryCandidates}}`
- `{{paymentMethodCandidates}}`
- `{{transcriptHint}}`
- `{{hasAudio}}`

## Expected response

The voice model must return JSON that decodes into `AutoLedgerParseEnvelope`.

Preferred response:

```json
{
  "entries": [
    {
      "amount": 58,
      "kind": "expense",
      "category": "餐饮",
      "paymentMethod": "微信",
      "time": "2026-04-27T12:30:00+08:00",
      "merchant": "",
      "note": "午饭",
      "rawText": "今天午饭 58 微信支付",
      "confidence": 0.91,
      "reason": "金额、用途和支付方式均来自原始音频。"
    }
  ],
  "recognizedEntryCount": 1,
  "primaryIndex": 0
}
```

Rules:

- return JSON only
- include `entries`, `recognizedEntryCount`, and `primaryIndex`
- do not invent amount, payment method, merchant, or time
- if a field is uncertain, lower `confidence` and explain it in `reason`
- if the audio contains multiple clear entries, return multiple records and point `primaryIndex` to the most reliable one

## Fallback behavior

The voice tab tries the cloud model first when `VOICE_LEDGER_AI_*` is configured.

If the remote path is unavailable or unusable, the app falls back to local parsing:

- remote config missing
- request failed
- non-2xx response
- stream decode failed
- final content is not valid `AutoLedgerParseEnvelope`

Fallback uses:

1. local `Speech.framework` transcript
2. local `AIParser.parseText(...)`

The result is still converted into a reviewable entry draft whenever possible.

## Review behavior

The user-facing review card is entry-aligned rather than raw-model-aligned.

It shows the concrete bookkeeping fields:

- amount
- income / expense kind
- category
- payment method
- time
- merchant / note

If the result is complete enough, the user can confirm and save immediately.
If key fields are still missing, the user can open the lightweight entry editor and finish the draft there.
