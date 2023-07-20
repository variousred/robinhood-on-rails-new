import { Controller } from "@hotwired/stimulus";
import { createConsumer } from "@rails/actioncable"
import { Turbo } from "@hotwired/turbo-rails"

export default class extends Controller {
  connect() {
    console.log("Connecting PositionsController")
    this.subscription = createCableSubscription(this)
  }

  disconnect() {
    this.subscription && this.subscription.unsubscribe()
  }

  update(data) {
    // handle the incoming data and change the DOM accordingly
    console.log("Received data: positions_controller.js", data)
    if (data.content) {
      Turbo.renderStreamMessage(data.content)
    }
  }
}

function createCableSubscription(controller) {
  console.log("Creating cable subscription")
  const consumer = createConsumer()
  const subscription = consumer.subscriptions.create(
    { channel: "PositionsAndQuotesChannel" },
    {
      received(data) {
        controller.update(data)
      }
    }
  )
  return subscription
}