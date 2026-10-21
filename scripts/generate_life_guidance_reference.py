#!/usr/bin/env python3
"""Import the complete HowToLiveBetter reference book, retaining source text."""

from __future__ import annotations

import json
import re
import argparse
import subprocess
from datetime import date
from pathlib import Path


SOURCE_REPO = "eternity4719/HowToLiveBetter"
SOURCE_COMMIT = "e73cb638b27f12a422546e5c09cadcac6fce03fe"
RETRIEVED_AT = "2026-10-08"
LICENSE = "CC BY 4.0"

OUTPUT = Path("Sources/Resources/LifeGuidance/life-guidance-reference.json")


def parse_cost_tags(line: str) -> dict[str, str]:
    result: dict[str, str] = {}
    match = re.search(r"成本标签:\s*(.*?)\s*-->", line)
    if not match:
        return result
    for token in match.group(1).split():
        if "=" in token:
            key, value = token.split("=", 1)
            result[key] = value
    return result


def parse_book_file(path: Path, section_number: int) -> dict:
    lines = path.read_text(encoding="utf-8").splitlines()
    heading_index = next((i for i, line in enumerate(lines) if re.match(r"^#\s+", line)), None)
    heading = re.sub(r"^#+\s+", "", lines[heading_index]).strip() if heading_index is not None else path.stem
    title = re.sub(r"^\d+\.\s*", "", heading)
    entries: list[dict] = []
    intro: list[str] = []
    current: dict | None = None
    current_body: list[str] = []
    current_field: str | None = None
    field_map = {
        "成本": "cost",
        "说人话": "humanSummary",
        "收益": "gain",
        "证据等级": "evidenceLevel",
        "来源": "source",
        "备注": "note",
    }

    def flush() -> None:
        nonlocal current, current_body, current_field
        if current is None:
            return
        current["rawMarkdown"] = "\n".join(current_body).strip()
        entries.append(current)
        current = None
        current_body = []
        current_field = None

    for line in lines[(heading_index + 1 if heading_index is not None else 0):]:
        entry_match = re.match(r"^###\s+(\d+)\.\s+(.+)$", line)
        if entry_match:
            flush()
            number = int(entry_match.group(1))
            current = {
                "id": f"life-reference.{section_number}.{number}",
                "number": number,
                "title": entry_match.group(2).strip(),
                "cost": "",
                "humanSummary": "",
                "gain": "",
                "evidenceLevel": "",
                "source": "",
                "note": "",
                "moneyCost": "",
                "timeCost": "",
                "willCost": "",
                "benefitLevel": "",
                "lens": "",
                "sourcePath": f"book/{path.name}",
                "sourceHeading": f"{number}. {entry_match.group(2).strip()}",
            }
            current_body = [line]
            continue
        if current is None:
            if line.strip() and not line.startswith("<!--"):
                intro.append(line.strip())
            continue
        current_body.append(line)
        tags = parse_cost_tags(line)
        if tags:
            current["moneyCost"] = tags.get("钱", "")
            current["timeCost"] = tags.get("时间", "")
            current["willCost"] = tags.get("毅力", "")
            current["benefitLevel"] = tags.get("收益", "")
            current["lens"] = tags.get("口径", "")
            continue
        field_match = re.match(r"^- (成本|说人话|收益|证据等级|来源|备注)：(.*)$", line)
        if field_match:
            current_field = field_map[field_match.group(1)]
            current[current_field] = field_match.group(2).strip()
        elif line.strip() and not line.startswith("<!--"):
            # Preserve any number of wrapped lines in the field they belong to.
            key = current_field or "note"
            current[key] = (current[key] + "\n" + line.strip()).strip()
    flush()
    return {
        "id": f"life-reference.section.{section_number}",
        "number": section_number,
        "title": title,
        "sourcePath": f"book/{path.name}",
        "intro": intro,
        "entries": entries,
    }


def parse_glossary(readme: str) -> list[dict[str, str]]:
    match = re.search(r"^## 读懂数字[^\n]*\n([\s\S]*?)(?=^## )", readme, re.MULTILINE)
    if not match:
        return []
    terms: list[dict[str, str]] = []
    for line in match.group(1).splitlines():
        row = re.match(r"^\|\s*(.+?)\s*\|\s*(.+?)\s*\|$", line)
        if row and row.group(1) != "术语" and not set(row.group(1)) <= {"-", " "}:
            terms.append({"term": row.group(1).strip(), "meaning": row.group(2).strip()})
    return terms


def parse_long_reads(root: Path) -> list[dict[str, str]]:
    documents = []
    for path in sorted((root / "docs").glob("*.md")):
        markdown = path.read_text(encoding="utf-8")
        first_heading = re.search(r"^#\s+(.+)$", markdown, re.MULTILINE)
        documents.append({
            "id": "life-reference.doc." + path.stem,
            "title": first_heading.group(1).strip() if first_heading else path.stem,
            "sourcePath": f"docs/{path.name}",
            "markdown": markdown,
        })
    return documents


def parse_readme_sections(readme: str) -> list[dict[str, str]]:
    """Keep the project's method, evidence, licensing, and other context in-app."""
    matches = list(re.finditer(r"^##\s+(.+)$", readme, re.MULTILINE))
    sections = []
    for index, match in enumerate(matches):
        start = match.start()
        end = matches[index + 1].start() if index + 1 < len(matches) else len(readme)
        markdown = readme[start:end].strip()
        title = match.group(1).strip()
        sections.append({
            "id": "life-reference.readme." + str(index + 1),
            "title": title,
            "markdown": markdown,
        })
    return sections


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--commit", default=SOURCE_COMMIT)
    parser.add_argument("--retrieved-at", default=RETRIEVED_AT)
    parser.add_argument("--output", type=Path, default=OUTPUT)
    parser.add_argument("--check", action="store_true", help="Compare against existing JSON without writing")
    args = parser.parse_args()
    if not re.fullmatch(r"[0-9a-f]{40}", args.commit):
        parser.error("--commit must be a full Git commit SHA")
    date.fromisoformat(args.retrieved_at)
    if (args.source / ".git").exists():
        actual = subprocess.check_output(["git", "-C", str(args.source), "rev-parse", "HEAD"], text=True).strip()
        if actual != args.commit:
            parser.error("source checkout does not match --commit")
        dirty = subprocess.check_output(["git", "-C", str(args.source), "status", "--porcelain", "--", "book", "docs", "README.md"], text=True)
        if dirty.strip():
            parser.error("source material has uncommitted changes")
    book_files = sorted((args.source / "book").glob("*.md"))
    sections = [parse_book_file(path, int(path.name.split("-", 1)[0])) for path in book_files]
    readme = (args.source / "README.md").read_text(encoding="utf-8")
    entry_count = sum(len(section["entries"]) for section in sections)
    readme_sections = parse_readme_sections(readme)
    documents = parse_long_reads(args.source)
    if not sections or any(not s["entries"] for s in sections):
        parser.error("source contains missing or empty chapters")
    ids = [e["id"] for s in sections for e in s["entries"]]
    if len(ids) != len(set(ids)):
        parser.error("duplicate entry IDs")
    for section in sections:
        for entry in section["entries"]:
            if any(not entry[key] for key in ("title", "cost", "humanSummary", "gain", "evidenceLevel", "source", "note", "rawMarkdown")):
                parser.error("incomplete entry: " + entry["id"])
    payload = {
        "schemaVersion": 1,
        "title": "高性价比人生指南",
        "summary": "完整离线人生指南。每天一条资料入口，回顾时也可遇见与事件相关的条目。",
        "sourceRepo": SOURCE_REPO,
        "sourceCommit": args.commit,
        "retrievedAt": args.retrieved_at,
        "license": LICENSE,
        "attribution": "内容来自《高性价比人生指南》，明思整理为离线条目，保留原文与来源。资料入口不代表针对个人的结论。",
        "counts": {"sections": len(sections), "entries": entry_count, "longReads": len(documents)},
        "sections": sections,
        "longReads": documents,
        "readmeSections": readme_sections,
        "glossary": parse_glossary(readme),
    }
    encoded = json.dumps(payload, ensure_ascii=False, indent=2) + "\n"
    if args.check:
        if args.output.read_text(encoding="utf-8") != encoded:
            parser.error("bundled JSON differs from the complete source import")
    else:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(encoded, encoding="utf-8")
    print(f"verified {args.output}: {len(sections)} sections, {entry_count} entries, {len(documents)} long reads, {len(payload['glossary'])} glossary terms")


if __name__ == "__main__":
    main()
