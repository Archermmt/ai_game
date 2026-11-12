#!/usr/bin/env python3
"""Package each Godot art study and optionally verify a clean, independent import.

Run from any directory:
    python3 tools/package_examples.py --output /tmp/art_delivery_20261109/packages --verify
"""
import argparse
from dataclasses import dataclass
import hashlib
import json
from pathlib import Path
import re
import subprocess
import tempfile
from zipfile import ZipFile, ZipInfo, ZIP_DEFLATED

ROOT = Path(__file__).resolve().parents[1]


@dataclass(frozen=True)
class Case:
    key: str
    title: str

    @property
    def assets(self):
        return Path("street" if self.key == "street" else f"examples/{self.key}")

    @property
    def scene(self):
        return (self.assets / f"{self.key}.tscn").as_posix()

    @property
    def docs(self):
        return Path(
            "docs/street" if self.key == "street" else f"docs/examples/{self.key}"
        )


CASES = [
    Case("street", "三渲二街道"),
    Case("island", "治愈风格小岛"),
    Case("cabin", "温馨林中小屋"),
    Case("desert", "低多边形沙漠营地"),
    Case("lava", "奇幻熔岩植物"),
]


def include(path):
    if path.is_symlink() or not path.is_file():
        return False
    excluded = {".git", ".godot", "__pycache__", ".DS_Store", ".cache"}
    return not excluded.intersection(path.parts) and not re.search(
        r"(?:\.blend[0-9]+|\.bak|\.pyc|~)$", path.name, re.IGNORECASE
    )


def included_files(case):
    directories = [
        case.assets,
        Path("examples/shared"),
        case.docs,
        Path("captures") / case.key,
    ]
    files = {Path(".gitignore"), Path("docs/.gdignore"), Path("captures/.gdignore")}
    files.update(path.relative_to(ROOT) for path in (ROOT / "tools").glob("offscreen_benchmark.gd*") if path.is_file())
    if case.key == "street":
        directories.append(Path("docs/references"))
        files.add(Path("docs/street.md"))
    for directory in directories:
        files.update(
            path.relative_to(ROOT)
            for path in (ROOT / directory).rglob("*")
            if include(path)
        )
    return sorted(files)


def project_config(case):
    config = (ROOT / "project.godot").read_text()
    for key, value in {
        "config/name": case.title,
        "run/main_scene": f"res://{case.scene}",
        "config/custom_user_dir_name": f"ArtStudy_{case.key}",
    }.items():
        config, count = re.subn(
            rf"^{re.escape(key)}=.*$", f'{key}="{value}"', config, flags=re.MULTILINE
        )
        if count != 1:
            raise ValueError(f"Expected one {key} setting, found {count}")
    return config.encode()


def readme(case):
    preview = (
        "captures/street/final/main.png"
        if case.key == "street"
        else f"captures/{case.key}/final.png"
    )
    return f"""# {case.title} · Godot 独立工程

![成片]({preview})

1. 将压缩包完整解压至新目录，在 Godot 4.7 项目管理器中选择“导入”，打开解压目录里的 `project.godot`。
2. 等待 GLB 和材质首次导入完成。按 F5 运行默认场景 `{case.scene}`。编辑器也可直接打开该场景，选择相机预览。
3. 在运行窗口拖动鼠标观察场景，滚轮缩放，按 R 恢复主镜头。
4. [美术制作手册与复盘]({case.docs.as_posix()}/制作手册与复盘.md)包含可编辑源文件位置、建模参数、渲染设定与迭代截图。

命令行运行（工作目录为解压目录）：

```sh
godot --headless --path . --import
godot --path .
```

本工程使用 Forward+ 渲染。本次成片使用 Godot 4.7 / macOS Metal。运行已经随工程提供的模型只需要 Godot；重新生成源模型时，依制作手册准备对应建模工具。运行截图保存在 `captures/{case.key}/`。
""".encode()


def add_entry(archive, name, data):
    info = ZipInfo(name, date_time=(1980, 1, 1, 0, 0, 0))
    info.compress_type = ZIP_DEFLATED
    info.create_system = 3
    mode = 0o755 if name.endswith(".sh") else 0o644
    info.external_attr = (0o100000 | mode) << 16
    archive.writestr(info, data, compress_type=ZIP_DEFLATED, compresslevel=6)


def package(case, output):
    destination = output / f"{case.key}.zip"
    with tempfile.NamedTemporaryFile(
        dir=output, suffix=".zip.tmp", delete=False
    ) as tmp:
        staging = Path(tmp.name)
    try:
        with ZipFile(staging, "w") as archive:
            add_entry(archive, "project.godot", project_config(case))
            add_entry(archive, "README.md", readme(case))
            for path in included_files(case):
                add_entry(archive, path.as_posix(), (ROOT / path).read_bytes())
            if case.scene not in archive.namelist():
                raise ValueError(f"Missing main scene {case.scene}")
        staging.chmod(0o644)
        staging.replace(destination)
    finally:
        staging.unlink(missing_ok=True)
    return destination


PROBE = """extends SceneTree

func _initialize() -> void:
    var path := str(ProjectSettings.get_setting("application/run/main_scene"))
    var packed := load(path) as PackedScene
    if packed == null:
        quit(2)
        return
    var scene := packed.instantiate()
    if scene == null:
        quit(3)
        return
    root.add_child(scene)
    inspect.call_deferred(scene, path)

func inspect(scene: Node, path: String) -> void:
    var cameras := scene.find_children("*", "Camera3D", true, false).size()
    var bodies := scene.find_children("*", "MeshInstance3D", true, false).size()
    var batches := scene.find_children("*", "MultiMeshInstance3D", true, false).size()
    print("PACKAGE_SCENE ", JSON.stringify({"main": path, "root": scene.name,
        "cameras": cameras, "meshes": bodies, "batches": batches}))
    quit(0 if cameras > 0 and (bodies + batches) > 0 else 4)
"""


def godot_run(engine, directory, options, log):
    command = [
        engine,
        "--headless",
        "--path",
        str(directory),
        "--log-file",
        str(log.with_name(log.stem + ".engine.log")),
        *options,
    ]
    completed = subprocess.run(command, capture_output=True, text=True, timeout=180)
    output = completed.stdout + completed.stderr
    log.write_text(output)
    # Godot may exit 0 after reporting an asset or script load failure.
    if completed.returncode or re.search(r"(?m)^\s*(?:SCRIPT )?ERROR:", output):
        raise RuntimeError(
            f"Godot verification failed ({completed.returncode}), see {log}"
        )
    return output


def verify(case, archive_path, run_dir, engine):
    case_dir = run_dir / case.key
    project = case_dir / "project"
    project.mkdir(parents=True)
    with ZipFile(archive_path) as archive:
        bad_file = archive.testzip()
        if bad_file:
            raise ValueError(f"Archive CRC mismatch: {bad_file}")
        archive.extractall(project)
    if (project / ".godot").exists():
        raise ValueError(f"{case.key} archive contains generated imports")
    godot_run(engine, project, ["--import"], case_dir / "01-import.log")
    probe = case_dir / "probe.gd"
    probe.write_text(PROBE)
    output = godot_run(
        engine, project, ["--script", str(probe)], case_dir / "02-load.log"
    )
    details = json.loads(re.search(r"^PACKAGE_SCENE (.+)$", output, re.MULTILINE)[1])
    if details["main"] != f"res://{case.scene}":
        raise ValueError(f"Wrong main scene: {details['main']}")
    godot_run(engine, project, ["--quit-after", "20"], case_dir / "03-default-run.log")
    details.update(
        first_import="passed",
        scene_parse="passed",
        default_entry="passed",
        size=archive_path.stat().st_size,
        sha256=hashlib.sha256(archive_path.read_bytes()).hexdigest(),
    )
    return details


def write_report(results, output, run_dir):
    lines = [
        "# 独立工程包验证记录",
        "",
        f"使用 Godot `{results['godot']}`，逐包检查 ZIP CRC，再解压至独立的空目录。",
        "每个工程从零导入资源，解析和实例化默认场景，检查相机与网格，然后使用默认项目入口运行 20 帧。",
        "本记录为 headless 验证。项目内的 captures 目录保存此前实际图形后端的成片。",
        "",
        "| 工程 | 默认场景 | 相机 | 网格节点 | MultiMesh 节点 | 包大小 | 结果 |",
        "| --- | --- | ---: | ---: | ---: | ---: | --- |",
    ]
    for key, item in results["checks"].items():
        lines.append(
            f"| {key}.zip | `{item['main']}` | {item['cameras']} | {item['meshes']} | "
            f"{item['batches']} | {item['size']:,} B | 均通过 |"
        )
    lines.extend(["", "## SHA-256", "", "```text"])
    for key, item in results["checks"].items():
        lines.append(f"{item['sha256']}  {key}.zip")
    lines.extend(
        ["```", "", f"本机的完整引擎日志、试验工程与 JSON 数据位于 `{run_dir}`。", ""]
    )
    (output / "验证记录.md").write_text("\n".join(lines))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--verify", action="store_true")
    parser.add_argument("--godot", default="godot")
    parser.add_argument("--case", choices=[c.key for c in CASES], action="append")
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    targets = [case for case in CASES if not args.case or case.key in args.case]
    if args.verify:
        run_dir = Path(tempfile.mkdtemp(prefix="verify-", dir=output.parent))
        engine = subprocess.check_output([args.godot, "--version"], text=True).strip()
        results = {"godot": engine, "checks": {}}
        print(f"Verification logs and extracted projects: {run_dir}", flush=True)
    for case in targets:
        destination = package(case, output)
        print(
            f"Packaged {destination.name}: {destination.stat().st_size:,} bytes",
            flush=True,
        )
        if args.verify:
            results["checks"][case.key] = verify(case, destination, run_dir, args.godot)
            (run_dir / "verification.json").write_text(
                json.dumps(results, ensure_ascii=False, indent=2) + "\n"
            )
            print(f"Verified {case.key}", flush=True)
    if args.verify:
        write_report(results, output, run_dir)
        print(run_dir / "verification.json")


if __name__ == "__main__":
    main()
