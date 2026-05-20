import { Controller } from "@hotwired/stimulus"

interface Suggestions {
  type_id: number | null
  priority_id: number | null
  assignee_id: number | null
  reason: string | null
}

export default class AiSmartFillController extends Controller<HTMLElement> {
  private observer: MutationObserver | null = null
  private debounceTimer: number | null = null
  private form: HTMLFormElement | null = null
  private pill: HTMLElement | null = null

  connect(): void {
    this.watchForForm()
  }

  disconnect(): void {
    this.observer?.disconnect()
    if (this.debounceTimer) window.clearTimeout(this.debounceTimer)
  }

  private watchForForm(): void {
    const form = document.getElementById("create-work-package-form") as HTMLFormElement | null
    if (form) {
      this.attachToForm(form)
      return
    }
    this.observer = new MutationObserver(() => {
      const f = document.getElementById("create-work-package-form") as HTMLFormElement | null
      if (f) {
        this.attachToForm(f)
        this.observer?.disconnect()
      }
    })
    this.observer.observe(document.body, { childList: true, subtree: true })
  }

  private attachToForm(form: HTMLFormElement): void {
    this.form = form
    this.pill = this.createPill()

    const subjectField = form.querySelector("[name='work_package[subject]']") as HTMLInputElement | null
    if (subjectField) {
      subjectField.addEventListener("input", () => {
        const value = subjectField.value.trim()
        if (this.debounceTimer) window.clearTimeout(this.debounceTimer)
        if (value.length < 3) {
          this.hidePill()
          return
        }
        this.debounceTimer = window.setTimeout(() => this.fetchSuggestions(value), 500)
      })
    }
  }

  private getProjectId(): number | null {
    if (!this.form) return null
    const action = this.form.getAttribute("action") || ""
    const match = action.match(/\/projects\/(\d+)/)
    return match ? parseInt(match[1], 10) : null
  }

  private createPill(): HTMLElement {
    const pill = document.createElement("div")
    pill.className = "ai-suggestion-pill"
    pill.hidden = true
    pill.innerHTML = `
      <span class="ai-suggestion-text"></span>
      <button class="ai-suggestion-apply-all" data-action="click->ai--smart-fill#applyAll">Apply</button>
      <button class="ai-suggestion-dismiss" data-action="click->ai--smart-fill#dismiss">×</button>
    `
    this.form?.parentNode?.insertBefore(pill, this.form?.nextSibling ?? null)
    return pill
  }

  applyAll(): void {
    if (!this.pill) return
    const data = this.pill.dataset
    this.applyField("type", data.suggestedType)
    this.applyField("priority", data.suggestedPriority)
    this.applyField("assignee", data.suggestedAssignee)
    this.hidePill()
  }

  dismiss(): void {
    this.hidePill()
  }

  private async fetchSuggestions(subject: string): Promise<void> {
    const projectId = this.getProjectId()
    if (!projectId || !this.pill) return

    try {
      const resp = await fetch(`/ai/projects/${projectId}/suggestions`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": this.getCsrfToken()
        },
        body: JSON.stringify({ subject, project_id: projectId })
      })
      if (!resp.ok) return
      const data: Suggestions = await resp.json()
      if (data.type_id || data.priority_id || data.assignee_id) {
        this.showPill(data)
      }
    } catch {
      // silently fall back
    }
  }

  private showPill(data: Suggestions): void {
    if (!this.pill) return
    this.pill.hidden = false
    this.pill.dataset.suggestedType = data.type_id?.toString() ?? ""
    this.pill.dataset.suggestedPriority = data.priority_id?.toString() ?? ""
    this.pill.dataset.suggestedAssignee = data.assignee_id?.toString() ?? ""

    let parts: string[] = []
    if (data.reason) parts.push(data.reason)
    if (data.type_id) parts.push("Type suggested")
    if (data.priority_id) parts.push("Priority suggested")
    if (data.assignee_id) parts.push("Assignee suggested")

    const textEl = this.pill.querySelector(".ai-suggestion-text")
    if (textEl) textEl.textContent = parts.join(" · ")
  }

  private hidePill(): void {
    if (this.pill) this.pill.hidden = true
  }

  private applyField(field: string, value: string | undefined): void {
    if (!value || !this.form) return
    const nameMap: Record<string, string> = {
      type: "work_package[type_id]",
      priority: "work_package[priority_id]",
      assignee: "work_package[assigned_to_id]"
    }
    const name = nameMap[field]
    if (!name) return
    const el = this.form.querySelector(`[name='${name}']`) as HTMLSelectElement | null
    if (el) {
      el.value = value
      el.dispatchEvent(new Event("change", { bubbles: true }))
    }
  }

  private getCsrfToken(): string {
    const meta = document.querySelector('meta[name="csrf-token"]')
    return meta?.getAttribute("content") ?? ""
  }
}
