---
name: html-upload
description: Publish a self-contained HTML file to lenovo over tailscale and return a stable URL I can open on any tailnet device. Use when I ask to upload, publish, host, or share an HTML page, plan, report, mock, or writeup on lenovo, or show it at a link, or when I paste a lenovo.tail138448.ts.net/plans URL. Not for repo HTML work; that is the html-plans planning skill.
---

# HTML upload to lenovo

Upload HTML plan files to the fleet server and get back one tailnet URL. The
server side is already built: lenovo's Caddy serves `/var/lib/html-plans` at

    https://lenovo.tail138448.ts.net/plans/<name>.html

reachable from any tailnet device: PC, dell, either phone.

## Workflow

1. Write the file locally first: fully self-contained, inline CSS and JS, no
   local file references, keep it under 500KB. Reuse the slug below when
   iterating the same artifact so the URL never changes, I keep my open tabs.
2. Name the file as `<slug>.html`: lowercase, hyphens, no spaces.
3. Upload:

       scp <local-file> lenovo-user-ts:/var/lib/html-plans/<slug>.html

   From the home LAN `lenovo-user` works too. Never root: SSH root login on
   lenovo is disabled.
4. Verify with the shell, never by opening a browser:

       curl -sI https://lenovo.tail138448.ts.net/plans/<slug>.html

   A 200 with `Content-Type: text/html` is success. Retry only on a real
   network error, not on a 404: a 404 means the scp failed, fix the scp.
5. Reply with, exactly: the URL, its size, and a one line description of what
   the page shows. Nothing else. Do not paste HTML back to me.

## Rules

- The URL is the deliverable: write it plainly inline so I can tap it, no
  attached screenshots of the page.
- If the first upload fails with a permission error, tell me; do not improvise
  a home directory or retry into a different path.
- This is for web pages only: never upload other file types through this path.
  Overwrite `<slug>.html` for updates, use a fresh slug for a new artifact.
- The page is a tailnet-private artifact, not a secret leak: if it embeds real
  private data (tokens, addresses, logs), confirm with a one line warning
  before uploading.
