$ErrorActionPreference = 'Stop'

$cudaHome = 'C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v12.8'
if (!(Test-Path (Join-Path $cudaHome 'bin\nvcc.exe'))) {
  if ($env:CUDA_PATH_V12_8) {
    $cudaHome = $env:CUDA_PATH_V12_8
  } else {
    throw 'CUDA Toolkit 12.8 not found at C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v12.8 or CUDA_PATH_V12_8.'
  }
}

$preferredMsvcVersions = @(
  '14.29.30133',
  '14.16.27023',
  '14.44.35207',
  '14.50.35717',
  '14.51.36223'
)

$clCandidates = Get-ChildItem 'C:\Program Files\Microsoft Visual Studio' -Recurse -Filter cl.exe -ErrorAction SilentlyContinue |
  Where-Object { $_.FullName -like '*\VC\Tools\MSVC\*\bin\HostX64\x64\cl.exe' } |
  ForEach-Object {
    $version = ($_.FullName -split '\\VC\\Tools\\MSVC\\')[1].Split('\')[0]
    $vcRoot = ($_.FullName -split '\\VC\\Tools\\MSVC\\')[0] + '\VC'
    [PSCustomObject]@{
      Version = $version
      ClPath = $_.FullName
      ClDir = $_.DirectoryName
      MsvcRoot = Split-Path $_.DirectoryName -Parent | Split-Path -Parent | Split-Path -Parent
      VcvarsPath = Join-Path $vcRoot 'Auxiliary\Build\vcvars64.bat'
    }
  }

$selectedToolchain = $null
foreach ($version in $preferredMsvcVersions) {
  $candidate = $clCandidates | Where-Object { $_.Version -eq $version -and (Test-Path $_.VcvarsPath) } | Select-Object -First 1
  if ($candidate) {
    $selectedToolchain = $candidate
    break
  }
}

if (-not $selectedToolchain) {
  $selectedToolchain = $clCandidates |
    Where-Object { Test-Path $_.VcvarsPath } |
    Sort-Object Version -Descending |
    Select-Object -First 1
}

if (-not $selectedToolchain) {
  throw 'Compatible MSVC toolchain not found. Install Visual Studio C++ Build Tools.'
}

$vcvars = $selectedToolchain.VcvarsPath
$clDir = $selectedToolchain.ClDir
$selectedMsvcVersion = $selectedToolchain.Version

$cmdFile = Join-Path $env:TEMP 'triposr-vcvars-env.cmd'
@(
  '@echo off',
  ('call "{0}" -vcvars_ver={1} >nul' -f $vcvars, $selectedMsvcVersion),
  'set'
) | Set-Content -Path $cmdFile -Encoding ASCII

$vcvarsEnv = & cmd.exe /d /c $cmdFile
Remove-Item $cmdFile -ErrorAction SilentlyContinue
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}

$vcvarsEnv | ForEach-Object {
  if ($_ -match '^(.*?)=(.*)$') {
    Set-Item -Path ("env:" + $matches[1]) -Value $matches[2]
  }
}

if (-not (Test-Path (Join-Path $clDir 'cl.exe'))) {
  throw ('Selected cl.exe not found at ' + $clDir)
}

$pythonExe = Join-Path $pwd.Path 'venv\Scripts\python.exe'
if (!(Test-Path $pythonExe)) {
  throw ('Python venv not found at ' + $pythonExe)
}

$kitVersion = Get-ChildItem 'C:\Program Files (x86)\Windows Kits\10\Include' -Directory |
  Sort-Object Name -Descending |
  Select-Object -First 1 -ExpandProperty Name
$sdkBinX64 = 'C:\Program Files (x86)\Windows Kits\10\bin\' + $kitVersion + '\x64'

$env:CUDA_HOME = $cudaHome
$env:CUDA_PATH = $cudaHome
$env:CUDACXX = Join-Path $cudaHome 'bin\nvcc.exe'
$env:CC = 'cl.exe'
$env:CXX = 'cl.exe'
$env:VIRTUAL_ENV = Join-Path $pwd.Path 'venv'
$env:NVCC_PREPEND_FLAGS = '-allow-unsupported-compiler'
$env:TORCH_CUDA_ARCH_LIST = '8.9+PTX'
$env:PATH = $clDir + ';' + (Join-Path $pwd.Path 'venv\Scripts') + ';' + (Join-Path $cudaHome 'bin') + ';' + $sdkBinX64 + ';' + $env:PATH
if (Test-Path (Join-Path $sdkBinX64 'rc.exe')) {
  $env:RC = Join-Path $sdkBinX64 'rc.exe'
}
if (Test-Path (Join-Path $sdkBinX64 'mt.exe')) {
  $env:MT = Join-Path $sdkBinX64 'mt.exe'
}

if ([string]::IsNullOrWhiteSpace($env:INCLUDE) -or [string]::IsNullOrWhiteSpace($env:LIB)) {
  $msvcRoot = Split-Path $clDir -Parent | Split-Path -Parent | Split-Path -Parent
  $includePaths = @(
    (Join-Path $msvcRoot 'include'),
    ('C:\Program Files (x86)\Windows Kits\10\Include\' + $kitVersion + '\ucrt'),
    ('C:\Program Files (x86)\Windows Kits\10\Include\' + $kitVersion + '\shared'),
    ('C:\Program Files (x86)\Windows Kits\10\Include\' + $kitVersion + '\um'),
    ('C:\Program Files (x86)\Windows Kits\10\Include\' + $kitVersion + '\winrt'),
    ('C:\Program Files (x86)\Windows Kits\10\Include\' + $kitVersion + '\cppwinrt')
  ) | Where-Object { Test-Path $_ }
  $libPaths = @(
    (Join-Path $msvcRoot 'lib\x64'),
    ('C:\Program Files (x86)\Windows Kits\10\Lib\' + $kitVersion + '\ucrt\x64'),
    ('C:\Program Files (x86)\Windows Kits\10\Lib\' + $kitVersion + '\um\x64')
  ) | Where-Object { Test-Path $_ }
  if ([string]::IsNullOrWhiteSpace($env:INCLUDE) -and $includePaths.Count -gt 0) {
    $env:INCLUDE = ($includePaths -join ';')
  }
  if ([string]::IsNullOrWhiteSpace($env:LIB) -and $libPaths.Count -gt 0) {
    $env:LIB = ($libPaths -join ';')
  }
  if ([string]::IsNullOrWhiteSpace($env:WindowsSdkDir)) {
    $env:WindowsSdkDir = 'C:\Program Files (x86)\Windows Kits\10\'
  }
  if ([string]::IsNullOrWhiteSpace($env:VCToolsInstallDir)) {
    $env:VCToolsInstallDir = $msvcRoot + '\'
  }
}

if ([string]::IsNullOrWhiteSpace($env:INCLUDE)) {
  throw 'INCLUDE missing after vcvars64.bat fallback'
}
if ([string]::IsNullOrWhiteSpace($env:LIB)) {
  throw 'LIB missing after vcvars64.bat fallback'
}

Write-Host '[triposr] CUDA_HOME=' $env:CUDA_HOME
Write-Host '[triposr] VCVARS=' $vcvars
Write-Host '[triposr] MSVC_VERSION=' $selectedMsvcVersion
Write-Host '[triposr] CLDIR=' $clDir
Write-Host '[triposr] WindowsSdkDir=' $env:WindowsSdkDir
Write-Host '[triposr] VCToolsInstallDir=' $env:VCToolsInstallDir
Write-Host '[triposr] INCLUDE=' $env:INCLUDE
Write-Host '[triposr] LIB=' $env:LIB
Write-Host '[triposr] SDK_BIN_X64=' $sdkBinX64
Write-Host '[triposr] RC=' $env:RC
Write-Host '[triposr] MT=' $env:MT

Write-Host '[triposr] NVCC_PREPEND_FLAGS=' $env:NVCC_PREPEND_FLAGS
Write-Host '[triposr] TORCH_CUDA_ARCH_LIST=' $env:TORCH_CUDA_ARCH_LIST

where.exe cl
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}
where.exe nvcc
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}
where.exe rc
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}
where.exe mt
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}

$pyCheck = @'
import re, shutil, subprocess, torch
nvcc = shutil.which("nvcc")
out = subprocess.check_output([nvcc, "--version"]).decode()
match = re.search(r"release ([0-9]+\.[0-9]+)", out)
actual = match.group(1) if match else "unknown"
print("torch_cuda", torch.version.cuda)
print("which_cl", shutil.which("cl"))
print("which_nvcc", nvcc)
print("nvcc_release", actual)
assert shutil.which("cl"), "cl.exe not found on PATH"
assert actual == torch.version.cuda, f"CUDA toolkit {actual} does not match torch CUDA {torch.version.cuda}"
'@
$pyCheckFile = Join-Path $env:TEMP 'triposr-torch-check.py'
Set-Content -Path $pyCheckFile -Value $pyCheck -Encoding ASCII
& $pythonExe $pyCheckFile
$pyExit = $LASTEXITCODE
Remove-Item $pyCheckFile -ErrorAction SilentlyContinue
if ($pyExit -ne 0) {
  exit $pyExit
}

$torchmcubesSrc = Join-Path $pwd.Path '..\cache\torchmcubes-src'
if (Test-Path $torchmcubesSrc) {
  Remove-Item -Recurse -Force $torchmcubesSrc
}

git clone --depth 1 https://github.com/cocktailpeanut/torchmcubes.git "$torchmcubesSrc"
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}

$setupPy = Join-Path $torchmcubesSrc 'setup.py'
$setupText = Get-Content $setupPy -Raw
$setupText = $setupText -replace "extra_compile_args=\['-DWITH_CUDA'\],", "extra_compile_args={'cxx': ['/DWITH_CUDA'], 'nvcc': ['-DWITH_CUDA', '-allow-unsupported-compiler']},"
$setupText = $setupText -replace "'build_ext': BuildExtension", "'build_ext': BuildExtension.with_options(use_ninja=False)"
Set-Content -Path $setupPy -Value $setupText -Encoding ASCII
Write-Host '[triposr] patched setup.py WITH_CUDA flags for MSVC (cxx=/DWITH_CUDA, nvcc=-DWITH_CUDA)'
Write-Host '[triposr] patched setup.py to disable ninja for torchmcubes build on Windows'

$macrosHeader = Join-Path $torchmcubesSrc 'cxx\macros.h'
$macrosText = Get-Content $macrosHeader -Raw
$macrosText = $macrosText -replace '#include <torch/extension.h>', '#include <ATen/ATen.h>'
Set-Content -Path $macrosHeader -Value $macrosText -Encoding ASCII

$cudaIncludeBlock = @(
  '#include <ATen/ATen.h>'
  '#include <ATen/core/TensorAccessor.h>'
) -join [Environment]::NewLine

$gridInterpCuda = Join-Path $torchmcubesSrc 'cxx\grid_interp_cuda.cu'
$gridInterpCudaText = Get-Content $gridInterpCuda -Raw
$gridInterpCudaText = $gridInterpCudaText -replace '#include <ATen/ATen.h>`r`n#include <ATen/core/TensorAccessor.h>', $cudaIncludeBlock
$gridInterpCudaText = $gridInterpCudaText -replace "#include <torch/extension.h>\r?\n#include <ATen/ATen.h>", $cudaIncludeBlock
$gridInterpCudaText = $gridInterpCudaText -replace '#include <torch/extension.h>', '#include <ATen/core/TensorAccessor.h>'
$gridInterpCudaText = $gridInterpCudaText -replace 'torch::PackedTensorAccessor32', 'at::PackedTensorAccessor32'
$gridInterpCudaText = $gridInterpCudaText -replace 'torch::RestrictPtrTraits', 'at::RestrictPtrTraits'
$gridInterpCudaText = $gridInterpCudaText -replace 'torch::Tensor', 'at::Tensor'
$gridInterpCudaText = $gridInterpCudaText -replace 'torch::zeros', 'at::zeros'
$gridInterpCudaText = $gridInterpCudaText -replace 'torch::TensorOptions\(\)', 'at::TensorOptions()'
$gridInterpCudaText = $gridInterpCudaText -replace 'torch::kFloat32', 'at::kFloat'
$gridInterpCudaText = $gridInterpCudaText -replace 'torch::kCUDA', 'at::kCUDA'
$gridInterpCudaText = $gridInterpCudaText -replace 'torch::TensorOptions\(\)\.dtype\(torch::kFloat32\)\.device\(torch::kCUDA, deviceId\)', 'at::TensorOptions().dtype(at::kFloat).device(at::kCUDA, deviceId)'
Set-Content -Path $gridInterpCuda -Value $gridInterpCudaText -Encoding ASCII

$mcubesCuda = Join-Path $torchmcubesSrc 'cxx\mcubes_cuda.cu'
$mcubesCudaText = Get-Content $mcubesCuda -Raw
$mcubesCudaText = $mcubesCudaText -replace '#include <ATen/ATen.h>`r`n#include <ATen/core/TensorAccessor.h>', $cudaIncludeBlock
$mcubesCudaText = $mcubesCudaText -replace "#include <torch/extension.h>\r?\n#include <ATen/ATen.h>", $cudaIncludeBlock
$mcubesCudaText = $mcubesCudaText -replace '#include <torch/extension.h>', '#include <ATen/core/TensorAccessor.h>'
$mcubesCudaText = $mcubesCudaText -replace 'torch::PackedTensorAccessor32', 'at::PackedTensorAccessor32'
$mcubesCudaText = $mcubesCudaText -replace 'torch::RestrictPtrTraits', 'at::RestrictPtrTraits'
$mcubesCudaText = $mcubesCudaText -replace 'std::vector<torch::Tensor>', 'std::vector<at::Tensor>'
$mcubesCudaText = $mcubesCudaText -replace 'torch::Tensor ', 'at::Tensor '
$mcubesCudaText = $mcubesCudaText -replace 'torch::zeros', 'at::zeros'
$mcubesCudaText = $mcubesCudaText -replace 'torch::TensorOptions\(\)', 'at::TensorOptions()'
$mcubesCudaText = $mcubesCudaText -replace 'torch::kFloat32', 'at::kFloat'
$mcubesCudaText = $mcubesCudaText -replace 'torch::kInt32', 'at::kInt'
$mcubesCudaText = $mcubesCudaText -replace 'torch::kCUDA', 'at::kCUDA'
$mcubesCudaText = $mcubesCudaText -replace 'torch::TensorOptions\(\)\.dtype\(at::kInt\)\.device\(at::kCPU\)', 'at::TensorOptions().dtype(at::kInt).device(at::kCPU)'
$mcubesCudaText = $mcubesCudaText -replace 'torch::TensorOptions\(\)\.dtype\(torch::kFloat32\)\.device\(torch::kCUDA, deviceId\)', 'at::TensorOptions().dtype(at::kFloat).device(at::kCUDA, deviceId)'
$mcubesCudaText = $mcubesCudaText -replace 'torch::TensorOptions\(\)\.dtype\(torch::kInt32\)\.device\(torch::kCUDA, deviceId\)', 'at::TensorOptions().dtype(at::kInt).device(at::kCUDA, deviceId)'
Set-Content -Path $mcubesCuda -Value $mcubesCudaText -Encoding ASCII

Write-Host '[triposr] patched torchmcubes CUDA sources to avoid torch/extension.h in nvcc units'

& $pythonExe -m pip install --no-build-isolation --force-reinstall --no-cache-dir -v "$torchmcubesSrc"
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}

$pyValidate = @'
import torch
import torchmcubes_module as m
exports = [x for x in dir(m) if "mcubes" in x or "grid_interp" in x]
print("torchmcubes_exports", exports)
assert hasattr(m, "mcubes_cuda"), "torchmcubes built without mcubes_cuda"
assert hasattr(m, "grid_interp_cuda"), "torchmcubes built without grid_interp_cuda"
'@
$pyValidateFile = Join-Path $env:TEMP 'triposr-torch-validate.py'
Set-Content -Path $pyValidateFile -Value $pyValidate -Encoding ASCII
& $pythonExe $pyValidateFile
$pyExit = $LASTEXITCODE
Remove-Item $pyValidateFile -ErrorAction SilentlyContinue
if ($pyExit -ne 0) {
  exit $pyExit
}
