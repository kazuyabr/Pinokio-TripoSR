const path = require("path")

module.exports = {
  version: "1.2",
  title: "TripoSR",
  description: "a state-of-the-art open-source model for fast feedforward 3D reconstruction from a single image, developed in collaboration between Tripo AI and Stability AI. https://huggingface.co/spaces/stabilityai/TripoSR",
  icon: "icon.png",
  menu: async (kernel) => {
    const installing = await kernel.running(__dirname, "install.js")
    const installed = await kernel.exists(__dirname, "app", "venv")
    const running = await kernel.running(__dirname, "start.js")

    if (installing) {
      return [{
        default: true,
        icon: "fa-solid fa-plug",
        text: "Installing",
        href: "install.js"
      }]
    }

    if (!installed) {
      return [{
        default: true,
        icon: "fa-solid fa-plug",
        text: "Install",
        href: "install.js"
      }]
    }

    if (running) {
      const local = kernel.memory.local[path.resolve(__dirname, "start.js")]

      if (local && local.url) {
        return [{
          default: true,
          icon: "fa-solid fa-rocket",
          text: "Open Web UI",
          href: local.url
        }, {
          icon: "fa-solid fa-terminal",
          text: "Terminal",
          href: "start.js"
        }]
      }

      return [{
        default: true,
        icon: "fa-solid fa-terminal",
        text: "Terminal",
        href: "start.js"
      }]
    }

    return [{
      default: true,
      icon: "fa-solid fa-power-off",
      text: "Start",
      href: "start.js"
    }, {
      icon: "fa-solid fa-plug",
      text: "Update",
      href: "update.js"
    }, {
      icon: "fa-solid fa-plug",
      text: "Install",
      href: "install.js"
    }, {
      icon: "fa-regular fa-circle-xmark",
      text: "Reset",
      href: "reset.js"
    }]
  }
}
