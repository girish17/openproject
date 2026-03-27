## 2024-05-24 - SQL Injection via string interpolation in Category#destroy
**Vulnerability:** In `app/models/category.rb`, `Category#destroy` used string interpolation in a raw SQL string to reassign work packages: `WorkPackage.where("category_id = #{id}").update_all("category_id = #{reassign_to.id}")`.
**Learning:** This is a vulnerability if user input reaches `reassign_to.id` (even if it's currently an integer from a related model) and is generally an unsafe practice in Rails.
**Prevention:** Always use parameterized queries (e.g. hash syntax) for `where` and `update_all`: `WorkPackage.where(category_id: id).update_all(category_id: reassign_to.id)`.
## 2024-05-24 - Cross-Site Scripting (XSS) via Array#join and html_safe
**Vulnerability:** Several places in the codebase were calling `array.join("<br/>".html_safe)` or similar string-joined `.html_safe` methods. This bypasses Rails' automatic HTML escaping for the individual elements in the array, making it vulnerable to XSS if any array element contains user input.
**Learning:** `array.join("string").html_safe` marks the entire resulting string as safe, allowing unescaped HTML from the array elements to be rendered.
**Prevention:** Always use Rails' built-in `safe_join(array, "<br/>".html_safe)` instead. `safe_join` ensures that each individual element of the array is properly HTML-escaped before being joined with the separator.
