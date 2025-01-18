import "phoenix_html";
import { Socket } from "phoenix";
import { LiveSocket } from "phoenix_live_view";
import topbar from "topbar";

let Hooks = {};

Hooks.CodeEntry = {
  mounted() {
    const container = this.el;
    const pushEvent = (event, payload) => this.pushEvent(event, payload);
    const codeLength = 6;
    const eventName = container.dataset.phxEvent;
    const hiddenInput = document.createElement("input");
    hiddenInput.type = "hidden";
    container.appendChild(hiddenInput);

    const digitContainer = document.createElement("div");
    digitContainer.classList.add("code-entry");
    container.appendChild(digitContainer);

    function createDigitInputs() {
      var inputs = [];
      for (let i = 0; i < codeLength; i++) {
        const input = document.createElement("input");
        input.type = "text";
        input.maxLength = 1;
        input.classList.add("code-input");
        digitContainer.appendChild(input);
        inputs.push(input);
      }
      return inputs;
    }

    const digitInputs = createDigitInputs();

    digitInputs.forEach((input, index) => {
      input.addEventListener("input", (event) => {
        if (event.target.value.length === 1 && index < digitInputs.length - 1) {
          digitInputs[index + 1].focus();
        }
        updateHiddenInput();
      });

      input.addEventListener("keydown", (event) => {
        if (
          event.key === "Backspace" &&
          event.target.value.length === 0 &&
          index > 0
        ) {
          digitInputs[index - 1].focus();
        } else if (
          event.key === "ArrowRight" &&
          index < digitInputs.length - 1
        ) {
          digitInputs[index + 1].focus();
        } else if (event.key === "ArrowLeft" && index > 0) {
          digitInputs[index - 1].focus();
        }
      });

      input.addEventListener("paste", (event) => {
        event.preventDefault();
        const pasteData = event.clipboardData.getData("text").trim();
        if (/^\w{3}-?\w{3}$/.test(pasteData)) {
          pasteData
            .replace("-", "")
            .split("")
            .forEach((digit, i) => {
              if (i < digitInputs.length) {
                digitInputs[i].value = digit;
              }
            });
          updateHiddenInput();
        }
      });
    });

    function updateHiddenInput() {
      let code = "";
      digitInputs.forEach((input) => {
        code += input.value;
      });
      hiddenInput.value = code;

      pushEvent(eventName, { code: code });
    }
  },
};

Hooks.Flash = {
  mounted() {
    // Auto-hide after 5 seconds
    setTimeout(() => {
      this.el.style.opacity = 0;
      setTimeout(() => {
        // Use the built-in clear flash event
        this.pushEvent("lv:clear-flash", {
          key: this.el.getAttribute("phx-value-key"),
        });
      }, 500);
    }, 5000);
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

window.addEventListener("clipcopy", async (e) => {
  const input = e.target;
  try {
    await navigator.clipboard.writeText(input.value);
  } catch (err) {
    console.error("Failed to copy text: ", err);
  }
});

liveSocket.connect();
window.liveSocket = liveSocket;
