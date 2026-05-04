from __future__ import annotations

from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parent
SITE_PACKAGES = ROOT / "app" / "venv" / "Lib" / "site-packages" / "gradio" / "templates" / "frontend" / "assets"


def replace_once(path: Path, old: str, new: str, label: str) -> str:
    text = path.read_text(encoding="utf-8")
    if new in text:
        return f"[skip] {label}: already patched"
    if old not in text:
        raise RuntimeError(f"Patch target not found for {label}: {path}")
    path.write_text(text.replace(old, new, 1), encoding="utf-8")
    return f"[patch] {label}: updated {path.name}"


def main() -> int:
    upload_asset = SITE_PACKAGES / "Upload-5eb3d513.js"
    model3d_asset = SITE_PACKAGES / "Index-3ddfa2bc.js"
    if not upload_asset.exists():
        raise FileNotFoundError(f"Missing Gradio upload asset: {upload_asset}")
    if not model3d_asset.exists():
        raise FileNotFoundError(f"Missing Gradio Model3D asset: {model3d_asset}")

    results = [
        replace_once(
            upload_asset,
            "let _files = files.map(f => new File([f], f.name));",
            "let _files = files;",
            "Preserve original browser File objects during upload",
        ),
        replace_once(
            model3d_asset,
            """  let url;\n  url = value.url;\n  babylonExports.SceneLoader.ShowLoadingScreen = false;\n  const extension = (() => {\n    const filename = (value == null ? void 0 : value.orig_name) || value.path || \"\";\n    const lastDot = filename.lastIndexOf(\".\");\n    return lastDot >= 0 ? filename.slice(lastDot) : \"\";\n  })();\n  babylonExports.SceneLoader.Append(\n    url,\n    \"\",\n    scene,\n    () => create_camera(scene, camera_position, zoom_speed, pan_speed),\n    void 0,\n    void 0,\n    extension\n  );\n  return scene;""",
            """  let url;\n  url = value.url;\n  babylonExports.SceneLoader.ShowLoadingScreen = false;\n  const extension = (() => {\n    const filename = (value == null ? void 0 : value.orig_name) || value.path || \"\";\n    const lastDot = filename.lastIndexOf(\".\");\n    return lastDot >= 0 ? filename.slice(lastDot) : \"\";\n  })();\n  const loadModel = (resolvedUrl) => {\n    const revoke = resolvedUrl !== url && resolvedUrl.startsWith(\"blob:\");\n    babylonExports.SceneLoader.Append(\n      resolvedUrl,\n      \"\",\n      scene,\n      () => {\n        create_camera(scene, camera_position, zoom_speed, pan_speed);\n        if (revoke)\n          URL.revokeObjectURL(resolvedUrl);\n      },\n      void 0,\n      () => {\n        if (revoke)\n          URL.revokeObjectURL(resolvedUrl);\n      },\n      extension\n    );\n  };\n  fetch(url).then((response) => {\n    if (!response.ok)\n      throw new Error(`Failed to fetch model asset: ${response.status}`);\n    return response.blob();\n  }).then((blob) => {\n    loadModel(URL.createObjectURL(blob));\n  }).catch(() => {\n    loadModel(url);\n  });\n  return scene;""",
            "Load Model3D assets through fetch/blob URLs before handing off to Babylon",
        )
    ]

    for line in results:
        print(line)
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(f"[error] {exc}", file=sys.stderr)
        raise
