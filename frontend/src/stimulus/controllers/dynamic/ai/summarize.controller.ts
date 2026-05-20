import { Controller } from "@hotwired/stimulus"

export default class AiSummarizeController extends Controller<HTMLElement> {
  static values = { workPackageId: Number }
  static targets = ["output"]

  declare workPackageIdValue: number
  declare readonly outputTarget: HTMLElement

  async summarize(event: Event): Promise<void> {
    event.preventDefault()

    this.outputTarget.hidden = false
    this.outputTarget.textContent = "Summarizing..."
    this.outputTarget.classList.add("ai-summary--loading")

    try {
      const resp = await fetch("/ai/summaries", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": this.getCsrfToken()
        },
        body: JSON.stringify({ work_package_id: this.workPackageIdValue })
      })
      if (!resp.ok) {
        this.outputTarget.textContent = "Summarization unavailable"
        return
      }
      const data = await resp.json()
      this.outputTarget.textContent = data.summary || "No summary available"
      this.outputTarget.classList.remove("ai-summary--loading")
    } catch {
      this.outputTarget.textContent = "Summarization unavailable"
      this.outputTarget.classList.remove("ai-summary--loading")
    }
  }

  private getCsrfToken(): string {
    const meta = document.querySelector('meta[name="csrf-token"]')
    return meta?.getAttribute("content") ?? ""
  }
}
