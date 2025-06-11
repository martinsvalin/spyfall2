// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html";
// Establish Phoenix Socket and LiveView configuration.
import { Socket } from "phoenix";
import { LiveSocket } from "phoenix_live_view";
import topbar from "../vendor/topbar";

let Hooks = {};

Hooks.GameTimer = {
  mounted() {
    this.startTime = null;
    this.timerId = null;
    this.initializeTimer();
  },

  updated() {
    this.initializeTimer();
  },

  destroyed() {
    this.clearExistingTimer();
  },

  initializeTimer() {
    this.clearExistingTimer();

    const startedAtISO = this.el.dataset.startedAt;
    this.startTime = new Date(startedAtISO);

    this.updateDisplay();
    this.timerId = setInterval(() => {
      this.updateDisplay();
    }, 1000);
  },

  clearExistingTimer() {
    if (this.timerId) {
      clearInterval(this.timerId);
      this.timerId = null;
    }
  },

  updateDisplay() {
    const now = new Date();
    const elapsedMilliseconds = now.getTime() - this.startTime.getTime();

    if (elapsedMilliseconds < 0) {
      return;
    }

    const totalElapsedSeconds = Math.floor(elapsedMilliseconds / 1000);
    const minutes = Math.floor(totalElapsedSeconds / 60);
    const seconds = totalElapsedSeconds % 60;
    const paddedSeconds = seconds < 10 ? `0${seconds}` : `${seconds}`;

    this.el.innerText = `${minutes}:${paddedSeconds}`;
  },
};

Hooks.NamePersister = {
  mounted() {
    const input = this.el;
    const storedName = localStorage.getItem("name");

    if (storedName) {
      input.value = storedName;
      this.pushEvent("update_name", { name: storedName });
    }

    input.addEventListener("input", (e) => {
      localStorage.setItem("name", e.target.value);
    });
  },
};

let csrfToken = document
  .querySelector("meta[name='csrf-token']")
  .getAttribute("content");

let liveSocket = new LiveSocket("/live", Socket, {
  hooks: Hooks,
  longPollFallbackMs: 2500,
  params: { _csrf_token: csrfToken },
});

// Show progress bar on live navigation and form submits
topbar.config({ barColors: { 0: "#29d" }, shadowColor: "rgba(0, 0, 0, .3)" });
window.addEventListener("phx:page-loading-start", (_info) => topbar.show(300));
window.addEventListener("phx:page-loading-stop", (_info) => topbar.hide());

// connect if there are any LiveViews on the page
liveSocket.connect();

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket;
