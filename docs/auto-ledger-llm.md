# Auto Ledger LLM (Screenshot / OCR)

This layer is intentionally independent from the Auto Ledger UI and shortcut flow.
It is only responsible for screenshot and OCR-based parsing. Voice bookkeeping stays on the local `Speech.framework` transcription path and does not use a cloud voice model.

## Environment keys

Use the variables from `.env.template`:

- `AUTO_LEDGER_OPENAI_ENDPOINT`
- `AUTO_LEDGER_OPENAI_API_KEY`
- `AUTO_LEDGER_OPENAI_MODEL`
- `AUTO_LEDGER_OPENAI_ENABLE_THINKING`
- `AUTO_LEDGER_OPENAI_SYSTEM_PROMPT`
- `AUTO_LEDGER_OPENAI_USER_PROMPT_TEMPLATE`

On iOS, the app reads these values from:

1. Xcode Scheme environment variables
2. `Info.plist`

It does **not** read `.env` directly at runtime.

## Call site

The entry point is `mobile_project/ViewModels/AutoLedgerLLM.swift`, and the request is sent from `mobile_project/ViewModels/AutoLedgerFlow.swift`.

`GatewayAutoLedgerService.parseReceipt(...)` sends an OpenAI Chat Completions request:

```json
{
  "model": "gpt-4.1-mini",
  "messages": [
    {
      "role": "system",
      "content": "..."
    },
    {
      "role": "user",
      "content": [
        { "type": "text", "text": "..." },
        { "type": "image_url", "image_url": { "url": "data:image/png;base64,..." } }
      ]
    }
  ],
  "response_format": { "type": "json_object" }
}
```

The OpenAI request now receives both:

- an image part: the original screenshot as a `data:image/png;base64,...` URL
- OCR text, merged from:
  - shortcut input `OCR 文本`
  - on-device Vision OCR over the screenshot

The model can use image understanding and text extraction together. The OCR channel is no longer optional in normal screenshot flows.

## Expected response

Preferred response JSON (returned as the assistant message content):

```json
{
  "entries": [
    {
      "amount": 53.3,
      "kind": "expense",
      "category": "餐饮",
      "paymentMethod": "微信",
      "time": "2026-04-12T18:55:00Z",
      "merchant": "KFC Hong Kong",
      "note": "自动识别：KFC Hong Kong",
      "rawText": "OCR or merged text",
      "confidence": 0.87,
      "reason": "根据金额行和商户行推断"
    }
  ],
  "recognizedEntryCount": 2,
  "primaryIndex": 0
}
```

Also supported:

- `{"result": {...}}` wrapper

## Required fields

The model must return these fields:

- `entries`: array of records, required
- `recognizedEntryCount`: integer >= 1, required
- `primaryIndex`: integer index in entries, required

If the screenshot contains multiple candidate records, the model should:

- return all reliable records in `entries`
- set `recognizedEntryCount` to the candidate count when it can estimate it
- set `primaryIndex` to the most reliable record

## Recognition scope

Current downstream mapping supports these semantic outputs well:

- `kind`
  - `expense`
  - `income`
- `category`
  - common expense classes such as `餐饮`, `交通`, `购物`, `住房`, `休闲娱乐`, `医疗健康`, `学习办公`, `宠物`, `母婴家庭`, `旅行`, `人情社交`, `数码`, `订阅`
  - common income classes such as `工资`, `退款`, `报销`, `理财`, `兼职`, `礼金`
  - work-specific classes from the selected scheme are also acceptable
- `paymentMethod`
  - `微信`
  - `支付宝`
  - `银行卡`
  - `现金`
  - exact account names from app context if the model can match them reliably
- `merchant`
  - store / restaurant / platform / bill counterparty name
- `time`
  - full payment time
  - bill detail time
  - screenshot-visible time when no transaction time is present should be treated as low confidence

The most important field is `amount`. If `amount` is missing or not numeric, the app treats the recognition as failed and will not auto-save.

## Prompt placeholders

`AUTO_LEDGER_OPENAI_USER_PROMPT_TEMPLATE` supports:

- `{{currencyCode}}`
- `{{localeIdentifier}}`
- `{{categoryCandidates}}`
- `{{paymentMethodCandidates}}`
- `{{rawOCR}}`
- `{{hasImage}}`

## Recommended prompt contract

Recommended `systemPrompt`:

```text
你是账单识别与结构化记账助手。你的任务是根据账单截图、OCR 文本和账本上下文，输出单条最可信的结构化记账结果。

硬性要求：
1. 只输出 JSON，不要输出 Markdown，不要输出解释性前后缀。
2. 顶层返回 JSON 对象，必须包含：entries, recognizedEntryCount, primaryIndex。
3. entries 元素必须包含：amount, kind, category, paymentMethod, time, merchant, note, rawText, confidence, reason。
4. 如果截图中有多笔候选记录，返回最可信的一笔，并在 recognizedEntryCount 和 reason 里说明。
5. 如果无法可靠识别 amount，就返回错误语义：amount=null，confidence<=0.35，并在 reason 里明确说明失败原因；不要编造金额。
6. 优先使用“实际支付金额/实付/收款金额/到账金额”，不要把标价、优惠前金额、汇率换算金额、列表页其他金额当作最终金额。
7. 优先使用交易时间或账单详情时间；只有在没有交易时间时才退化到截图可见时间，并降低 confidence。
8. rawText 必须填入你实际依赖的 OCR 证据摘要；note 写成简短中文备注；merchant 尽量输出商户或收付款对象。
```

Recommended `userPromptTemplate`:

```text
请根据输入内容提取一条最可信的账单记录。

账本上下文：
- currencyCode={{currencyCode}}
- localeIdentifier={{localeIdentifier}}
- categoryCandidates={{categoryCandidates}}
- paymentMethodCandidates={{paymentMethodCandidates}}
- hasImage={{hasImage}}

OCR 文本如下：
{{rawOCR}}

输出要求：
- 返回 JSON 对象（含 entries 数组）
- 如果 category 无法精确命中，可以返回最接近的中文类别
- 如果 paymentMethod 无法确定，返回“待确认”
- 如果 merchant 无法确定，返回空字符串
- 如果时间只有时分，没有日期，请结合当前上下文补全今天日期，并在 reason 中说明
- 如果截图是教程页、安装页、快捷指令编辑页、纯系统界面或非账单图片，不要编造金额
```

## Notes

- If the LLM config is incomplete, the app falls back to local OCR.
- If local OCR also fails, the app now returns failure instead of injecting fake values like `18.50`.
- The shortcut no longer needs to reopen the app after recognition. `识别账单` now saves directly through the shared persistence layer.
