# 🚀 Telegram Notify for GitHub Actions

GitHub Action for sending Telegram notification messages **with topic (forum) support**.

## ✨ Features

- ✅ Send text messages (Markdown or HTML format)
- ✅ **Send to forum topics** using `message_thread_id`
- ✅ Send photo attachments
- ✅ Send document attachments
- ✅ Disable link previews
- ✅ Silent notifications

## 📖 Usage

### Basic Usage

```yml
name: Telegram Notification
on: [push]

jobs:
  notify:
    runs-on: ubuntu-latest
    steps:
      - name: Send Telegram Message
        uses: Dev4Mod/telegram-github-action@main
        with:
          to: ${{ secrets.TELEGRAM_CHAT_ID }}
          token: ${{ secrets.TELEGRAM_BOT_TOKEN }}
          message: |
            🚀 New push to ${{ github.repository }}

            Commit: ${{ github.event.head_commit.message }}
            Author: ${{ github.actor }}
```

### 📌 Send to Topic (Forum)

For supergroups with topics enabled, you can send messages to a specific topic:

```yml
- name: Send to CI Topic
  uses: Dev4Mod/telegram-github-action@main
  with:
    to: ${{ secrets.TELEGRAM_CHAT_ID }}
    token: ${{ secrets.TELEGRAM_BOT_TOKEN }}
    message_thread_id: ${{ secrets.TELEGRAM_THREAD_ID }}
    message: |
      ✅ Build #${{ github.run_number }} successful!
```

### 📷 Send with Photo

```yml
- name: Send Photo
  uses: Dev4Mod/telegram-github-action@main
  with:
    to: ${{ secrets.TELEGRAM_CHAT_ID }}
    token: ${{ secrets.TELEGRAM_BOT_TOKEN }}
    message_thread_id: "123" # Optional: send to topic
    photo: "./screenshot.png"
    message: "Build screenshot"
```

### 🖼️ Send Multiple Photos

```yml
- name: Send Photos
  uses: Dev4Mod/telegram-github-action@main
  with:
    to: ${{ secrets.TELEGRAM_CHAT_ID }}
    token: ${{ secrets.TELEGRAM_BOT_TOKEN }}
    photo: "./a.png,./b.png,./c.png"
    message: "Build screenshots"
```

### 📄 Send with Document

```yml
- name: Send Document
  uses: Dev4Mod/telegram-github-action@main
  with:
    to: ${{ secrets.TELEGRAM_CHAT_ID }}
    token: ${{ secrets.TELEGRAM_BOT_TOKEN }}
    document: "./build-report.pdf"
```

### 📎 Send Multiple Documents

```yml
- name: Send Documents
  uses: Dev4Mod/telegram-github-action@main
  with:
    to: ${{ secrets.TELEGRAM_CHAT_ID }}
    token: ${{ secrets.TELEGRAM_BOT_TOKEN }}
    document: "./report.pdf,./logs.txt"
```


## 📥 Input Parameters

| Parameter                  | Required | Description                                           |
| -------------------------- | -------- | ----------------------------------------------------- |
| `to`                       | ✅       | Telegram chat ID (user, group, or channel)            |
| `token`                    | ✅       | Telegram Bot API token                                |
| `message`                  | ❌       | Message text to send                                  |
| `message_file`             | ❌       | Path to file containing message (overrides `message`) |
| `message_thread_id`        | ❌       | Topic ID for forum supergroups                        |
| `photo`                    | ❌       | Path(s) to photo file(s) to send                      |
| `document`                 | ❌       | Path(s) to document file(s) to send                   |

| `format`                   | ❌       | Message format: `markdown` or `html`                  |
| `disable_web_page_preview` | ❌       | Disable link preview (default: `false`)               |
| `disable_notification`     | ❌       | Send silently (default: `false`)                      |

## 🔑 Getting Credentials

### Bot Token

1. Message [@BotFather](https://t.me/BotFather) on Telegram
2. Send `/newbot` and follow the instructions
3. Copy the token provided

### Chat ID

For **private chats** or **groups**:

```bash
curl https://api.telegram.org/bot<TOKEN>/getUpdates
```

Look for `"chat": {"id": 123456789}` in the response.

### Message Thread ID (Topic)

For **forum topics**:

1. Send a message to the topic from Telegram app
2. Right-click the message → "Copy Message Link"
3. Link format: `https://t.me/c/<chat_id>/<thread_id>/<msg_id>`
4. The `<thread_id>` is your `message_thread_id`

## 🔧 Secrets Configuration

This action uses **GitHub Environment Secrets** for secure credential storage.

### Step 1: Create Environment

1. Go to your repository on GitHub
2. Navigate to **Settings** → **Environments**
3. Click **New environment**
4. Name it `Telegram Github Action` (or your preferred name)
5. Click **Configure environment**

### Step 2: Add Secrets

In the environment configuration page:

1. Scroll to **Environment secrets**
2. Click **Add environment secret**
3. Add the following secrets:

| Secret               | Description                            |
| -------------------- | -------------------------------------- |
| `TELEGRAM_BOT_TOKEN` | Bot API token from BotFather           |
| `TELEGRAM_CHAT_ID`   | Chat ID to send messages to            |
| `TELEGRAM_THREAD_ID` | _(Optional)_ Topic ID for forum groups |

### Step 3: Update Workflow

Add the `environment` field to your workflow job:

```yml
jobs:
  notify:
    runs-on: ubuntu-latest
    environment: "Telegram Github Action"  # ← Add this line
    steps:
      - name: Send Telegram Message
        uses: Dev4Mod/telegram-github-action@main
        with:
          to: ${{ secrets.TELEGRAM_CHAT_ID }}
          token: ${{ secrets.TELEGRAM_BOT_TOKEN }}
          message: "Hello from GitHub Actions!"
```

> **Note:** The `environment` name must match exactly with the environment you created in Step 1.

## 📜 License

MIT License - see [LICENSE](LICENSE) file for details.

---

Based on [appleboy/telegram-action](https://github.com/appleboy/telegram-action), rewritten with native topic support.
