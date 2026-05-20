import { Controller } from "@hotwired/stimulus"

export default class AiChatToggleController extends Controller<HTMLElement> {
  toggle(): void {
    window.dispatchEvent(new CustomEvent("ai:chat:toggle"))
  }
}
