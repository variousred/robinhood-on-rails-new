import { Controller } from "@hotwired/stimulus";
import { Turbo } from "@hotwired/turbo-rails";

export default class extends Controller {
  static values = { updateUrl: String };

  connect() {
    console.log("Connecting PollerController");
    // this.connectionId = this.generateUniqueId();
    // console.log(`Connection ID: ${this.connectionId}`);
    // this.stopPolling();
    // this.startPolling();
  }

  disconnect() {
    console.log(`Disconnecting PollerController ${this.connectionId}`);
    // this.stopPolling();
  }


  async poll() {
    const response = await fetch(this.updateUrlValue, {
      headers: {
        "Accept": "text/vnd.turbo-stream.html",
      },
    });

    if (response.ok) {
      const contentType = response.headers.get("content-type");
      if (contentType && contentType.includes("text/vnd.turbo-stream.html")) {
        const turboStreamResponse = await response.text();
        Turbo.renderStreamMessage(turboStreamResponse);
        this.updateTimeElapsed();
      }
    }
  }

  updateTimeElapsed() {
    console.log(`Updating time elapsed ${this.connectionId}`);
    const timeElapsedElement = document.getElementById("time-elapsed");
    if (timeElapsedElement) {
      timeElapsedElement.textContent = "Just now";
      if (this.secondsInterval) clearInterval(this.secondsInterval);

      let seconds = 0;
      this.secondsInterval = setInterval(() => {
        seconds++;
        const timeLabel = seconds < 60 ? `${seconds} seconds ago` : `${Math.floor(seconds / 60)} minutes ago`;
        timeElapsedElement.textContent = timeLabel;
      }, 1000);
    }
  }

  startPolling() {
    console.log(`Starting polling ${this.connectionId}`);
    this.pollInterval = setInterval(() => this.poll(), 1000);
  }

  stopPolling() {
    console.log(`Stopping polling ${this.connectionId}`);
    if (this.pollInterval) {
      clearInterval(this.pollInterval);
      this.pollInterval = null;
    }
    if (this.secondsInterval) {
      clearInterval(this.secondsInterval);
      this.secondsInterval = null;
    }
  }

  generateUniqueId() {
    return Math.random().toString(36).substr(2, 9);
  }
}