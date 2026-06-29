import { Controller } from "@hotwired/stimulus"

export default class AiSearchController extends Controller<HTMLInputElement> {
  static targets = ["results"]
  static values = {
    url: String,
    redirectUrl: String
  }

  declare readonly resultsTarget: HTMLElement
  declare readonly inputTarget: HTMLInputElement
  declare urlValue: string
  declare redirectUrlValue: string

  private debounceTimer: number | null = null
  private lastQuery: string = ""

  query(event: InputEvent): void {
    const value = (event.target as HTMLInputElement).value.trim()

    if (this.debounceTimer) {
      window.clearTimeout(this.debounceTimer)
    }

    if (value.length < 2) {
      this.resultsTarget.hidden = true
      this.lastQuery = ""
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
    this.lastQuery = query

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

  private renderSuggestions(data: { q: string; scope: string; filters: Record<string, unknown>; results: unknown[]; summary?: string; count: number }): void {
    if (!data.results || data.results.length === 0) {
      this.resultsTarget.innerHTML = `
        <div class="ai-search-suggestion ai-search-no-results">
          <div class="ai-search-summary">No results found for "${this.escapeHtml(data.q)}"</div>
          <button class="ai-search-go" data-action="click->ai--search#go">
            Search anyway →
          </button>
        </div>
      `
      return
    }

    const scopeLabel = data.scope === "work_packages" ? "Work packages" :
                       data.scope === "projects" ? "Projects" : "Everything"

    let resultsHtml = ""
    if (data.results.length > 0) {
      const topResults = data.results.slice(0, 5) as Array<{id: number; subject?: string; name?: string; type?: string; status?: string; project?: string; url: string}>
      resultsHtml = `<div class="ai-search-results-list">
        ${topResults.map(r => `
          <div class="ai-search-result-item">
            <a href="${r.url}" class="ai-search-result-link">
              <span class="ai-search-result-title">${this.escapeHtml(r.subject || r.name || "")}</span>
              <span class="ai-search-result-meta">${[r.type, r.status, r.project].filter(Boolean).join(" · ")}</span>
            </a>
          </div>
        `).join("")}
        ${data.count > 5 ? `<div class="ai-search-more">+${data.count - 5} more results</div>` : ""}
      </div>`
    }

    this.resultsTarget.innerHTML = `
      <div class="ai-search-suggestion">
        ${data.summary ? `<div class="ai-search-summary">${this.escapeHtml(data.summary)}</div>` : ""}
        ${resultsHtml}
        <div class="ai-search-footer">
          <span class="ai-search-count">${data.count} result${data.count !== 1 ? "s" : ""}</span>
          <button class="ai-search-go" data-action="click->ai--search#go">
            View all →
          </button>
        </div>
      </div>
    `
  }

  go(): void {
    if (this.lastQuery) {
      const params = new URLSearchParams({ q: this.lastQuery })
      window.location.href = `${this.redirectUrlValue}?${params.toString()}`
    } else {
      window.location.href = this.redirectUrlValue
    }
  }

  private escapeHtml(text: string): string {
    const div = document.createElement("div")
    div.textContent = text
    return div.innerHTML
  }
}
