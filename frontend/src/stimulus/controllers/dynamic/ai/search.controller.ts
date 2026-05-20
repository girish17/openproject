import { Controller } from "@hotwired/stimulus"

export default class AiSearchController extends Controller<HTMLInputElement> {
  static targets = ["results"]
  static values = {
    url: String,
    redirectUrl: String
  }

  declare readonly resultsTarget: HTMLElement
  declare urlValue: string
  declare redirectUrlValue: string

  private debounceTimer: number | null = null

  query(event: InputEvent): void {
    const value = (event.target as HTMLInputElement).value.trim()

    if (this.debounceTimer) {
      window.clearTimeout(this.debounceTimer)
    }

    if (value.length < 2) {
      this.resultsTarget.hidden = true
      return
    }

    this.debounceTimer = window.setTimeout(() => this.fetchSuggestions(value), 300)
  }

  focus(event: FocusEvent): void {
    if ((event.target as HTMLInputElement).value.trim().length >= 2) {
      this.resultsTarget.hidden = false
    }
  }

  private async fetchSuggestions(query: string): Promise<void> {
    this.resultsTarget.hidden = false
    this.resultsTarget.textContent = "Searching..."

    try {
      const csrfToken = document.querySelector('meta[name="csrf-token"]')?.getAttribute("content") || ""
      const resp = await fetch(this.urlValue, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": csrfToken
        },
        body: JSON.stringify({ query })
      })
      if (!resp.ok) {
        this.resultsTarget.textContent = "AI search unavailable"
        return
      }
      const data = await resp.json()
      this.renderSuggestions(data)
    } catch {
      this.resultsTarget.textContent = "Search unavailable"
    }
  }

  private renderSuggestions(data: { q: string; scope: string; filters: Record<string, unknown> }): void {
    const scopeLabel = data.scope === "work_packages" ? "Work packages" :
                       data.scope === "projects" ? "Projects" : "Everything"

    const filterParts: string[] = []
    if (data.filters) {
      if (data.filters.status) filterParts.push(`status: ${data.filters.status}`)
      if (data.filters.assignee) filterParts.push(`assignee: ${data.filters.assignee}`)
      if (data.filters.priority) filterParts.push(`priority: ${data.filters.priority}`)
      if (data.filters.type) filterParts.push(`type: ${data.filters.type}`)
    }

    this.resultsTarget.innerHTML = `
      <div class="ai-search-suggestion">
        <strong>Search:</strong> ${this.escapeHtml(data.q)}
        <div class="ai-search-meta">
          <span class="ai-search-scope">${scopeLabel}</span>
          ${filterParts.length ? `<span class="ai-search-filters">${filterParts.join(" · ")}</span>` : ""}
        </div>
        <button class="ai-search-go" data-action="click->ai--search#go">
          Search →
        </button>
      </div>
    `
  }

  go(): void {
    window.location.href = this.redirectUrlValue
  }

  private escapeHtml(text: string): string {
    const div = document.createElement("div")
    div.textContent = text
    return div.innerHTML
  }
}
