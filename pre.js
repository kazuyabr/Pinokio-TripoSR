module.exports = (config, kernel) => {
  const x = {
    win32: {
      nvidia: `uv pip install torch torchvision torchaudio ${config.xformers ? 'xformers' : ''} --index-url https://download.pytorch.org/whl/cu128`,
      amd: "uv pip install torch-directml",
      cpu: "uv pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu"
    },
    darwin: "uv pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu",
    linux: {
      nvidia: `uv pip install torch torchvision torchaudio ${config.xformers ? 'xformers' : ''}`,
      amd: "uv pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/rocm5.7",
      cpu: "uv pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu"
    }
  }

  if (!config.torch) {
    return null
  }

  if (kernel.platform === "darwin") {
    return x[kernel.platform]
  }

  return x[kernel.platform][kernel.gpu]
}
