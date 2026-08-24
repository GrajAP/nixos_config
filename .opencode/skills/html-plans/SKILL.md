---
name: html-plans
description: Use ONLY when the user mentions HTML in any way - writing, editing, building pages, components, templates, emails, or UI markup. Before touching any HTML, always produce a plan first and get approval.
---

# HTML plans

Any mention of HTML means the user wants a plan about it first. Never write,
edit, or generate HTML immediately.

Theo (t3.gg) style: think before you type, keep markup simple, and treat HTML
as the product surface - not an afterthought.

## Workflow

1. **Stop.** Do not emit any HTML tags yet.
2. **Plan** the change and present it to the user:
   - Goal: what the page/component/markup must do.
   - Structure: outline of elements and hierarchy (semantic tags: header, nav, main, section, article, footer) as a short tree or list.
   - Semantics & accessibility: headings order, landmarks, alt text, labels, focus order.
   - Content: what text/data goes where, where dynamic values come from.
   - Styling hook strategy: class naming (BEM or existing project conventions), minimal CSS surface, no framework bloat unless already used.
   - Edge cases: empty states, long text, mobile layout, i18n.
3. **Wait for approval** of the plan.
4. Only after approval, implement exactly what was planned. If scope changes mid-implementation, stop and re-plan.

## Rules

- Prefer semantic HTML over div/span soup; add ARIA only when semantics cannot express it.
- Keep plans short and scannable - bullet lists, not essays.
- If the request is tiny (e.g., one attribute), still state the one-line plan before editing.
