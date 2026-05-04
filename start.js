module.exports = async (kernel) => {
  const tempDir = kernel.platform === "win32"
    ? "..\\cache\\GRADIO_TEMP_DIR"
    : "../cache/GRADIO_TEMP_DIR"
  const launchMessage = kernel.platform === "win32"
    ? [
        `if not exist "${tempDir}" mkdir "${tempDir}"`,
        `set "GRADIO_TEMP_DIR=${tempDir}"`,
        `set "TMP=${tempDir}"`,
        `set "TEMP=${tempDir}"`,
        "python app.py"
      ]
    : [
        `mkdir -p "${tempDir}"`,
        `export GRADIO_TEMP_DIR="${tempDir}"`,
        `export TMP="${tempDir}"`,
        `export TEMP="${tempDir}"`,
        "python app.py"
      ]

  return {
    daemon: true,
    run: [{
      method: "shell.run",
      params: {
        path: ".",
        venv: "app/venv",
        message: "python patch_gradio.py"
      }
    }, {
      method: "shell.run",
      params: {
        path: "app",
        venv: "venv",
        message: launchMessage,
        on: [{
          event: "/(http:\/\/[0-9.:]+)/",
          done: true
        }]
      }
    }, {
      method: "local.set",
      params: {
        url: "{{input.event[1]}}"
      }
    }]
  }
}
