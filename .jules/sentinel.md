## 2024-05-24 - [Fix XSS in array joins]
**Vulnerability:** XSS in views when joining arrays with HTML safe strings (e.g. `@errors.join("<br/>".html_safe)`).
**Learning:** In Rails, calling `join` on an array with an `html_safe` string separator bypasses escaping for the array elements, leading to Cross-Site Scripting (XSS) if the array contains user input.
**Prevention:** Always use the Rails built-in `safe_join` helper for this purpose: `safe_join(@errors, "<br/>".html_safe)`.
