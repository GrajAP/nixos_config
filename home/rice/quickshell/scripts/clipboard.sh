set -euo pipefail

action="${1:-list}"
encoded="${2:-}"
mime_type="${3:-}"

decode_entry() {
  if [[ -z "$encoded" ]]; then
    echo "Missing clipboard entry" >&2
    exit 2
  fi
  printf '%s' "$encoded" | base64 -d
}

case "$action" in
  list)
    python3 - <<'PY'
if True:
      import base64
      from html import escape
      from html.parser import HTMLParser
      import json
      import os
      from pathlib import Path
      import re
      import subprocess
      from urllib.parse import unquote, urlparse
      from xml.etree import ElementTree as ET

      MAX_RICH_TEXT_BYTES = 256 * 1024
      MAX_RENDERED_CHARS = 12000
      MAX_SVG_BYTES = 8 * 1024 * 1024
      RICH_FILE_SUFFIXES = {".htm", ".html", ".markdown", ".md", ".svg"}
      IMAGE_MIME_TYPES = {
          "bmp": "image/bmp",
          "gif": "image/gif",
          "jpeg": "image/jpeg",
          "jpg": "image/jpeg",
          "png": "image/png",
          "tif": "image/tiff",
          "tiff": "image/tiff",
          "webp": "image/webp",
      }
      IMAGE_PATTERN = re.compile(
          r"^\[\[ binary data .*? (png|jpe?g|webp|gif|bmp|tiff?) (\d+)x(\d+) \]\]$",
          re.IGNORECASE,
      )
      RICH_PREVIEW_PATTERN = re.compile(
          r"(?:<\?xml|<svg\b|<!doctype\s+html|<html\b|<body\b|<head\b|<div\b|<p\b|<table\b|"
          r"^#{1,6}\s|```|\[[^\]]+\]\([^)]+\)|(?:^|\s)[-*+]\s+)",
          re.IGNORECASE,
      )
      SVG_PATTERN = re.compile(r"<svg\b", re.IGNORECASE)
      HTML_PATTERN = re.compile(
          r"(?:<!doctype\s+html|<html\b|<body\b|<head\b|<(?:article|div|main|p|section|table)\b)",
          re.IGNORECASE,
      )
      MARKDOWN_PATTERN = re.compile(
          r"(?:^|\n)(?:#{1,6}\s+|>\s+|[-*+]\s+|\d+\.\s+)|```|\[[^\]]+\]\([^)]+\)|\*\*[^*]+\*\*",
          re.MULTILINE,
      )

      class SafeHtml(HTMLParser):
          allowed_tags = {
              "b", "blockquote", "br", "code", "del", "em", "h1", "h2", "h3",
              "h4", "h5", "h6", "hr", "i", "li", "ol", "p", "pre", "s",
              "small", "strong", "sub", "sup", "u", "ul",
          }
          void_tags = {"br", "hr"}
          skipped_tags = {"embed", "iframe", "noscript", "object", "script", "style"}

          def __init__(self):
              super().__init__(convert_charrefs=True)
              self.parts = []
              self.skip_depth = 0

          def handle_starttag(self, tag, _attrs):
              tag = tag.lower()
              if tag in self.skipped_tags:
                  self.skip_depth += 1
              elif self.skip_depth == 0 and tag in self.allowed_tags:
                  self.parts.append(f"<{tag}>")

          def handle_startendtag(self, tag, _attrs):
              tag = tag.lower()
              if self.skip_depth == 0 and tag in self.void_tags:
                  self.parts.append(f"<{tag}>")

          def handle_endtag(self, tag):
              tag = tag.lower()
              if tag in self.skipped_tags and self.skip_depth > 0:
                  self.skip_depth -= 1
              elif self.skip_depth == 0 and tag in self.allowed_tags and tag not in self.void_tags:
                  self.parts.append(f"</{tag}>")

          def handle_data(self, data):
              if self.skip_depth == 0:
                  self.parts.append(escape(data))

          def result(self):
              return "".join(self.parts)[:MAX_RENDERED_CHARS].strip()

      def compact_text(value, limit=180):
          compact = " ".join(value.split())
          return compact if len(compact) <= limit else compact[:limit - 3] + "..."

      def decode_clip(entry_id):
          decoded = subprocess.run(
              ["cliphist", "decode", entry_id],
              check=False,
              stdout=subprocess.PIPE,
              stderr=subprocess.DEVNULL,
          )
          if decoded.returncode != 0:
              raise RuntimeError("cliphist decode failed")
          return decoded.stdout

      def atomic_write(path, data):
          temporary_path = path.with_name(f".{path.name}.tmp")
          temporary_path.write_bytes(data)
          temporary_path.replace(path)

      def numeric_svg_length(value):
          match = re.match(r"^\s*([0-9]+(?:\.[0-9]+)?)", value or "")
          return max(1, round(float(match.group(1)))) if match else 0

      def svg_dimensions(data):
          root = ET.fromstring(data)
          if root.tag.rsplit("}", 1)[-1].lower() != "svg":
              raise ValueError("not an SVG root")
          width = numeric_svg_length(root.attrib.get("width", ""))
          height = numeric_svg_length(root.attrib.get("height", ""))
          view_box = re.split(r"[\s,]+", root.attrib.get("viewBox", "").strip())
          if len(view_box) == 4:
              try:
                  view_width = max(1, round(float(view_box[2])))
                  view_height = max(1, round(float(view_box[3])))
                  width = width or view_width
                  height = height or view_height
              except ValueError:
                  pass
          return width or 800, height or 600

      def local_rich_file(data):
          text = data.decode("utf-8", "replace")
          for line in text.splitlines():
              candidate = line.strip()
              if candidate.startswith("file://"):
                  parsed = urlparse(candidate)
                  if parsed.netloc not in ("", "localhost"):
                      continue
                  path = Path(unquote(parsed.path))
              elif candidate.startswith("/"):
                  path = Path(candidate)
              else:
                  continue
              if path.suffix.lower() in RICH_FILE_SUFFIXES and path.is_file():
                  return path
          return None

      def safe_markdown(value):
          value = re.sub(r"!\[([^\]]*)\]\([^)]+\)", r"[Image: \1]", value)
          return value[:MAX_RENDERED_CHARS].strip()

      def sanitized_html(value):
          parser = SafeHtml()
          parser.feed(value)
          parser.close()
          return parser.result()

      def html_source_preview(value):
          compact = " ".join(value.split())
          return f"<code>{escape(compact[:MAX_RENDERED_CHARS])}</code>"

      entries = []
      active_preview_names = set()
      runtime_dir = Path(os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}"))
      preview_dir = runtime_dir / "quickshell-clipboard-previews"
      result = subprocess.run(
          ["cliphist", "list"],
          check=False,
          stdout=subprocess.PIPE,
          stderr=subprocess.DEVNULL,
          text=True,
      )

      for raw in result.stdout.splitlines()[:80]:
          if not raw:
              continue
          parts = raw.split("\t", 1)
          entry_id = parts[0].strip()
          preview = parts[1].strip() if len(parts) > 1 else raw.strip()
          entry = {
              "id": entry_id,
              "line": base64.b64encode(raw.encode("utf-8", "replace")).decode("ascii"),
              "preview": compact_text(preview) or "(empty)",
              "searchText": "",
              "kind": "text",
              "mimeType": "",
              "imagePath": "",
              "imageWidth": 0,
              "imageHeight": 0,
              "richText": "",
              "sourceName": "",
          }

          image_match = IMAGE_PATTERN.match(preview)
          if image_match and entry_id.isdigit():
              image_format, image_width, image_height = image_match.groups()
              image_format = image_format.lower()
              try:
                  preview_dir.mkdir(mode=0o700, parents=True, exist_ok=True)
                  image_name = f"{entry_id}.{image_format}"
                  image_path = preview_dir / image_name
                  if not image_path.exists():
                      atomic_write(image_path, decode_clip(entry_id))
                  active_preview_names.add(image_name)
                  entry.update({
                      "kind": "image",
                      "mimeType": IMAGE_MIME_TYPES.get(image_format, f"image/{image_format}"),
                      "preview": f"Image · {image_format.upper()} · {image_width} × {image_height}",
                      "imagePath": str(image_path),
                      "imageWidth": int(image_width),
                      "imageHeight": int(image_height),
                  })
              except (OSError, RuntimeError):
                  pass
          elif entry_id.isdigit() and (
              RICH_PREVIEW_PATTERN.search(preview)
              or re.search(r"(?:file://|/)\S+\.(?:svg|md|markdown|html?|htm)(?:\s|$)", preview, re.IGNORECASE)
          ):
              try:
                  decoded = decode_clip(entry_id)
                  rich_file = local_rich_file(decoded)
                  source_name = rich_file.name if rich_file else ""
                  suffix = rich_file.suffix.lower() if rich_file else ""
                  content = rich_file.read_bytes() if rich_file else decoded

                  if (suffix == ".svg" or SVG_PATTERN.search(content[:4096].decode("utf-8", "ignore"))) and len(content) <= MAX_SVG_BYTES:
                      image_width, image_height = svg_dimensions(content)
                      preview_dir.mkdir(mode=0o700, parents=True, exist_ok=True)
                      image_name = f"{entry_id}.svg"
                      image_path = preview_dir / image_name
                      atomic_write(image_path, content)
                      active_preview_names.add(image_name)
                      entry.update({
                          "kind": "svg",
                          "mimeType": "" if rich_file else "image/svg+xml",
                          "preview": f"SVG · {image_width} × {image_height}" + (f" · {source_name}" if source_name else ""),
                          "imagePath": str(image_path),
                          "imageWidth": image_width,
                          "imageHeight": image_height,
                          "sourceName": source_name,
                      })
                  elif len(content) <= MAX_RICH_TEXT_BYTES:
                      text = content.decode("utf-8", "replace")
                      if suffix in (".html", ".htm") or HTML_PATTERN.search(text[:4096]):
                          rendered = sanitized_html(text)
                          rendered_as_source = not rendered
                          if rendered_as_source:
                              rendered = html_source_preview(text)
                          entry.update({
                              "kind": "html",
                              "mimeType": "" if rich_file else "text/html;charset=utf-8",
                              "preview": "HTML" + (
                                  f" · {source_name}"
                                  if source_name
                                  else (" · source preview" if rendered_as_source else " · formatted content")
                              ),
                              "richText": rendered,
                              "searchText": compact_text(text, 1000),
                              "sourceName": source_name,
                          })
                      elif suffix in (".md", ".markdown") or MARKDOWN_PATTERN.search(text):
                          rendered = safe_markdown(text)
                          entry.update({
                              "kind": "markdown",
                              "mimeType": "",
                              "preview": "Markdown" + (f" · {source_name}" if source_name else " · formatted content"),
                              "richText": rendered,
                              "searchText": compact_text(rendered, 1000),
                              "sourceName": source_name,
                          })
              except (ET.ParseError, OSError, RuntimeError, ValueError):
                  pass

          entries.append(entry)

      if preview_dir.exists():
          for preview_path in preview_dir.iterdir():
              if preview_path.is_file() and not preview_path.name.startswith(".") and preview_path.name not in active_preview_names:
                  try:
                      preview_path.unlink()
                  except OSError:
                      pass

      print(json.dumps(entries, ensure_ascii=False))
PY
    ;;
  copy)
    if [[ -n "$mime_type" ]]; then
      decode_entry | cliphist decode | wl-copy --type "$mime_type"
    else
      decode_entry | cliphist decode | wl-copy
    fi
    notify-send -u low -t 1500 "Clipboard" "Copied from history."
    ;;
  delete)
    entry="$(decode_entry)"
    entry_id="${entry%%$'\t'*}"
    printf '%s' "$entry" | cliphist delete
    if [[ "$entry_id" =~ ^[0-9]+$ ]]; then
      preview_dir="${XDG_RUNTIME_DIR:-/run/user/$UID}/quickshell-clipboard-previews"
      rm -f "$preview_dir/$entry_id".*
    fi
    notify-send -u low -t 1500 "Clipboard" "Removed entry."
    ;;
  wipe)
    cliphist wipe
    rm -rf "${XDG_RUNTIME_DIR:-/run/user/$UID}/quickshell-clipboard-previews"
    notify-send -u normal -t 1800 "Clipboard" "History cleared."
    ;;
  *)
    echo "Usage: quickshell-clipboard [list|copy ENTRY [MIME]|delete ENTRY|wipe]" >&2
    exit 2
    ;;
esac
