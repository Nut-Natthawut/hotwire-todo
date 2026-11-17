import { Controller } from "@hotwired/stimulus"

// Clears the form after a successful Turbo submit, ready for the next task.
//
// <form data-controller="reset-form" data-action="turbo:submit-end->reset-form#reset">
//   <div data-reset-form-target="errors">…</div>
// </form>
export default class extends Controller {
  static targets = ["errors"]

  // turbo:submit-end fires after every submit; detail.success is true only for a 2xx response.
  reset(event) {
    if (!event.detail.success) return

    this.element.reset()
    this.errorsTargets.forEach((element) => element.remove())
  }
}
