import { Controller } from "@hotwired/stimulus"

export default class AiChatController extends Controller {
  static targets = ["messages", "input", "sendButton", "conversations"]

  declare readonly messagesTarget: HTMLElement
  declare readonly inputTarget: HTMLTextAreaElement
  declare readonly sendButtonTarget: HTMLButtonElement
  declare readonly conversationsTarget: HTMLElement

  private conversationId: string | null = null
  private eventSource: EventSource | null = null

  connect(): void {
    this.inputTarget.addEventListener("keydown", (e: KeyboardEvent) => {
      if (e.key === "Enter" && !e.shiftKey) {
        e.preventDefault()
        this.send()
      }
    })
  }

  disconnect(): void {
    this.closeStream()
  }

  async send(): Promise<void> {
    const content = this.inputTarget.value.trim()
    if (!content) return

    this.appendMessage("user", content)
    this.inputTarget.value = ""
    this.setLoading(true)

    if (!this.conversationId) {
      const resp = await this.createConversation()
      this.conversationId = resp.id
    }

    const messageResp = await fetch(`/ai/conversations/${this.conversationId}/messages`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ content })
    })

    if (!messageResp.ok) {
      this.appendMessage("assistant", "AI is unavailable. Check that Ollama is running.")
      this.setLoading(false)
      return
    }

    this.openStream()
  }

  newConversation(): void {
    this.conversationId = null
    this.messagesTarget.innerHTML = ""
    this.closeStream()
  }

  private async createConversation(): Promise<{ id: string }> {
    const resp = await fetch("/ai/conversations", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ title: this.inputTarget.value.slice(0, 50) })
    })
    return resp.json()
  }

  private openStream(): void {
    this.closeStream()
    this.eventSource = new EventSource(`/ai/conversations/${this.conversationId}/stream`)

    const assistantMsg = this.appendMessage("assistant", "")
    const contentSpan = assistantMsg.querySelector(".ai-message-content")!

    this.eventSource.onmessage = (e: MessageEvent) => {
      contentSpan.textContent += e.data
    }

    this.eventSource.onerror = () => {
      this.setLoading(false)
    }

    this.eventSource.addEventListener("done", () => {
      this.closeStream()
      this.setLoading(false)
    })
  }

  private closeStream(): void {
    this.eventSource?.close()
    this.eventSource = null
  }

  private appendMessage(role: string, content: string): HTMLElement {
    const div = document.createElement("div")
    div.className = `ai-message ai-message--${role}`
    div.innerHTML = `
      <div class="ai-message-avatar">${role === "user" ? "U" : "AI"}</div>
      <div class="ai-message-content">${this.escapeHtml(content)}</div>
    `
    this.messagesTarget.appendChild(div)
    this.messagesTarget.scrollTop = this.messagesTarget.scrollHeight
    return div
  }

  private setLoading(loading: boolean): void {
    this.sendButtonTarget.disabled = loading
    this.inputTarget.disabled = loading
  }

  private escapeHtml(text: string): string {
    const div = document.createElement("div")
    div.textContent = text
    return div.innerHTML
  }
}
