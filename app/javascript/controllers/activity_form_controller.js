import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["treadmillFields", "treadmillInput"]

  connect() {
    this.toggle()
  }

  toggle() {
    const onTreadmill = this.treadmillInputTargets.some((input) => input.checked && input.value === "1")
    this.treadmillFieldsTargets.forEach((element) => element.classList.toggle("hidden", !onTreadmill))
  }
}
