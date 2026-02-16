"""
Сборщик md -> pdf для руководства пользователя.
Использует pandoc и wkhtmltopdf. Без подписи.
"""
from __future__ import annotations

import argparse
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path


class ToolError(RuntimeError):
    pass


# Чтобы русские сообщения не превращались в "����" в некоторых консольных окружениях
if sys.platform.startswith("win"):
    try:
        sys.stdout.reconfigure(encoding="utf-8")  # type: ignore[attr-defined]
        sys.stderr.reconfigure(encoding="utf-8")  # type: ignore[attr-defined]
    except Exception:
        pass


def _fail(msg: str, *, code: int = 2) -> None:
    print(msg, file=sys.stderr)
    raise SystemExit(code)


def _run_checked(cmd: list[str], *, what: str) -> subprocess.CompletedProcess[str]:
    try:
        p = subprocess.run(cmd, text=True, capture_output=True)
    except FileNotFoundError as e:
        raise ToolError(
            f"Не найден исполняемый файл для шага: {what}\n"
            f"Команда: {cmd[0]!r}\n"
            f"Ошибка: {e}"
        ) from e

    if p.returncode != 0:
        raise ToolError(
            f"Команда завершилась с ошибкой при шаге: {what}\n"
            f"Код: {p.returncode}\n"
            f"Команда: {' '.join(cmd)}\n"
            f"STDOUT:\n{p.stdout}\n"
            f"STDERR:\n{p.stderr}"
        )
    return p


def resolve_exe_with_fallbacks(
    *,
    explicit: str | None,
    env_key: str,
    program_name: str,
    fallbacks: list[Path],
) -> str:
    if explicit:
        return explicit
    v = os.environ.get(env_key)
    if v:
        return v
    found = shutil.which(program_name)
    if found:
        return found
    for p in fallbacks:
        if p and p.exists():
            return str(p)
    return program_name


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(
        description="md -> pdf (pandoc + wkhtmltopdf, без подписи)",
    )
    ap.add_argument(
        "--input",
        default="docs/РУКОВОДСТВО_ПОЛЬЗОВАТЕЛЯ.md",
        help="Путь к .md (по умолчанию: docs/РУКОВОДСТВО_ПОЛЬЗОВАТЕЛЯ.md)",
    )
    ap.add_argument(
        "--outdir",
        default="docs",
        help="Папка для результата PDF (по умолчанию: docs)",
    )
    ap.add_argument(
        "--output",
        default=None,
        help="Имя выходного PDF без расширения (по умолчанию: из имени входного .md)",
    )
    ap.add_argument(
        "--pandoc",
        default=None,
        help="Путь к pandoc.exe (если не в PATH). Можно через env PANDOC_PATH.",
    )
    ap.add_argument(
        "--wkhtmltopdf",
        default=None,
        help="Путь к wkhtmltopdf.exe (если не в PATH). Можно через env WKHTMLTOPDF_PATH.",
    )
    ap.add_argument("--keep-html", action="store_true", help="Не удалять промежуточный HTML (для отладки)")
    ap.add_argument(
        "--title-page",
        default=None,
        help="Путь к отдельному .md с титульным листом (будет вставлен первым)",
    )
    ap.add_argument(
        "--version",
        default=None,
        help="Версия для колонтитула на каждой странице PDF (например: 2.0.1)",
    )
    args = ap.parse_args(argv)

    script_dir = Path(__file__).resolve().parent
    css_path = script_dir / "templates" / "default.css"
    if not css_path.exists():
        _fail(f"Не найден CSS-шаблон: {css_path}")

    input_path = Path(args.input)
    if not input_path.exists():
        _fail(f"Не найден входной файл: {input_path}")

    outdir = Path(args.outdir)
    outdir.mkdir(parents=True, exist_ok=True)

    output_basename = args.output or input_path.stem
    if not output_basename:
        output_basename = "document"

    md_dir = input_path.resolve().parent

    localapp = Path(os.environ.get("LOCALAPPDATA", ""))
    pandoc_exe = resolve_exe_with_fallbacks(
        explicit=args.pandoc,
        env_key="PANDOC_PATH",
        program_name="pandoc",
        fallbacks=[
            script_dir / "tools" / "pandoc" / "pandoc-3.9" / "pandoc.exe",
            Path(r"C:\Program Files\Pandoc\pandoc.exe"),
            Path(r"C:\Program Files (x86)\Pandoc\pandoc.exe"),
            localapp / "Pandoc" / "pandoc.exe",
        ],
    )
    wkhtml_exe = resolve_exe_with_fallbacks(
        explicit=args.wkhtmltopdf,
        env_key="WKHTMLTOPDF_PATH",
        program_name="wkhtmltopdf",
        fallbacks=[
            Path(r"C:\Program Files\wkhtmltopdf\bin\wkhtmltopdf.exe"),
            Path(r"C:\Program Files (x86)\wkhtmltopdf\bin\wkhtmltopdf.exe"),
        ],
    )

    md_text = input_path.read_text(encoding="utf-8")
    if args.title_page:
        title_path = Path(args.title_page)
        if not title_path.exists():
            _fail(f"Не найден файл титульного листа: {title_path}")
        title_content = title_path.read_text(encoding="utf-8")
        md_text = title_content + "\n\n<div style=\"page-break-after: always;\"></div>\n\n" + md_text
    title = "Руководство пользователя"  # для metadata title

    keep_html = bool(args.keep_html)
    with tempfile.TemporaryDirectory(prefix="build_pdf_") as td:
        td_path = Path(td)
        md_tmp = td_path / "document.md"
        html_tmp = td_path / "document.html"
        pdf_tmp = td_path / "document.pdf"

        # Копируем md и media в temp, чтобы пути к изображениям работали
        md_tmp.write_text(md_text, encoding="utf-8")
        media_src = md_dir / "media"
        if media_src.exists():
            media_dst = td_path / "media"
            shutil.copytree(media_src, media_dst)

        # resource-path: temp dir (где лежат md и media)
        resource_path = str(td_path)

        try:
            _run_checked(
                [
                    pandoc_exe,
                    "-f",
                    "markdown",
                    "-t",
                    "html5",
                    "--standalone",
                    "--metadata",
                    f"title={title}",
                    "--resource-path",
                    resource_path,
                    "--css",
                    str(css_path),
                    "-o",
                    str(html_tmp),
                    str(md_tmp),
                ],
                what="md -> html (pandoc)",
            )
        except ToolError as e:
            _fail(
                str(e)
                + "\n\n"
                "Не удалось выполнить pandoc.\n"
                "Установите pandoc и добавьте в PATH, либо укажите путь через --pandoc / env PANDOC_PATH."
            )

        wkhtml_cmd = [
            wkhtml_exe,
            "--enable-local-file-access",
            "--page-size",
            "A4",
            "--margin-top",
            "20mm",
            "--margin-bottom",
            "25mm",
            "--margin-left",
            "25mm",
            "--margin-right",
            "15mm",
        ]
        if args.version:
            wkhtml_cmd.extend(
                [
                    "--footer-center",
                    f"Версия {args.version}",
                    "--footer-font-size",
                    "9",
                    "--footer-spacing",
                    "5",
                ]
            )
        wkhtml_cmd.extend([str(html_tmp), str(pdf_tmp)])

        try:
            _run_checked(wkhtml_cmd, what="html -> pdf (wkhtmltopdf)")
        except ToolError as e:
            _fail(
                str(e)
                + "\n\n"
                "Не удалось выполнить wkhtmltopdf.\n"
                "Установите wkhtmltopdf и добавьте в PATH, либо укажите путь через --wkhtmltopdf / env WKHTMLTOPDF_PATH."
            )

        pdf_path = outdir / f"{output_basename}.pdf"
        if pdf_path.exists():
            pdf_path.unlink()
        shutil.move(str(pdf_tmp), str(pdf_path))

        if keep_html:
            html_copy = outdir / f"{output_basename}.html"
            html_copy.write_text(html_tmp.read_text(encoding="utf-8"), encoding="utf-8")
            print("WROTE_HTML", html_copy)

    print("WROTE_PDF", pdf_path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
