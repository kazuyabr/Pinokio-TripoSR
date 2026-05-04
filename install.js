const config = require("./config.js")
const pre = require("./pre.js")

module.exports = async (kernel) => {
  const torch = pre(config, kernel)
  const env = {}

  if (kernel.platform === "win32" && kernel.gpu === "nvidia") {
    env.DISTUTILS_USE_SDK = "1"
    env.FORCE_CUDA = "1"
    env.NVCC_PREPEND_FLAGS = "-allow-unsupported-compiler"
  }

  const installSteps = []

  if (torch) {
    installSteps.push(torch)
  }

  if (kernel.platform === "win32") {
    installSteps.push(
      "powershell -NoProfile -Command \"$root = $pwd.Path.ToLower(); $venv = ($pwd.Path + '\\venv').ToLower(); Get-CimInstance Win32_Process | Where-Object { ($_.Name -eq 'python.exe' -or $_.Name -eq 'pythonw.exe') -and $_.CommandLine -and ( $_.CommandLine.ToLower().Contains($venv) -or $_.CommandLine.ToLower().Contains($root) -or $_.CommandLine.ToLower().Contains('venv\\scripts\\python') -or $_.CommandLine.ToLower().Contains('infer-web.py') -or $_.CommandLine.ToLower().Contains('from app import run_example') ) } | ForEach-Object { Write-Host ('[triposr] stop pid=' + $_.ProcessId + ' name=' + $_.Name + ' cmd=' + $_.CommandLine); Stop-Process -Id $_.ProcessId -Force }\"",
      "powershell -NoProfile -Command \"Start-Sleep -Seconds 3\""
    )
  }

  installSteps.push(
    "if exist \"venv\\Lib\\site-packages\\pydantic_core\" rmdir /s /q \"venv\\Lib\\site-packages\\pydantic_core\"",
    "if exist \"venv\\Lib\\site-packages\\pydantic_core-2.14.6.dist-info\" rmdir /s /q \"venv\\Lib\\site-packages\\pydantic_core-2.14.6.dist-info\"",
    "if exist \"venv\\Lib\\site-packages\\pydantic_core-2.46.3.dist-info\" rmdir /s /q \"venv\\Lib\\site-packages\\pydantic_core-2.46.3.dist-info\"",
    "if exist \"venv\\Lib\\site-packages\\pydantic\" rmdir /s /q \"venv\\Lib\\site-packages\\pydantic\"",
    "if exist \"venv\\Lib\\site-packages\\pydantic-2.5.3.dist-info\" rmdir /s /q \"venv\\Lib\\site-packages\\pydantic-2.5.3.dist-info\"",
    "uv pip install --reinstall --no-deps pydantic==2.5.3 pydantic-core==2.14.6",
    "uv pip install -r requirements.txt --upgrade --refresh",
    "uv pip install --upgrade --refresh --no-deps gradio==4.8.0 fastapi==0.104.1 starlette==0.27.0",
    "uv pip install --upgrade --refresh --no-deps huggingface-hub==0.17.3 Pillow==10.1.0 typer==0.9.0 transformers==4.35.0",
    "uv pip install -U setuptools wheel ninja",
    "python ..\\patch_gradio.py"
  )

  if (kernel.platform === "win32" && kernel.gpu === "nvidia") {
    installSteps.push(
      "powershell -NoProfile -ExecutionPolicy Bypass -File ..\\build_torchmcubes.ps1"
    )
  } else {
    installSteps.push(
      "uv pip install --no-build-isolation --force-reinstall --no-cache-dir -v git+https://github.com/cocktailpeanut/torchmcubes.git"
    )
  }

  return {
    run: [{
      method: "shell.run",
      params: {
        message: "git clone https://huggingface.co/spaces/cocktailpeanut/TripoSR app",
        when: "{{!exists('app')}}"
      }
    }, {
      method: "shell.run",
      params: {
        venv: "venv",
        path: "app",
        env,
        message: installSteps
      }
    }, {
      method: "notify",
      params: {
        html: "Click the 'start' tab to get started!"
      }
    }]
  }
}
