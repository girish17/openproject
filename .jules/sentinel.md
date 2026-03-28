## 2024-05-24 - SQL Injection via string interpolation in Category#destroy
**Vulnerability:** In `app/models/category.rb`, `Category#destroy` used string interpolation in a raw SQL string to reassign work packages: `WorkPackage.where("category_id = #{id}").update_all("category_id = #{reassign_to.id}")`.
**Learning:** This is a vulnerability if user input reaches `reassign_to.id` (even if it's currently an integer from a related model) and is generally an unsafe practice in Rails.
**Prevention:** Always use parameterized queries (e.g. hash syntax) for `where` and `update_all`: `WorkPackage.where(category_id: id).update_all(category_id: reassign_to.id)`.
## 2026-03-28 - [XSS via Array#join with html_safe]
**Vulnerability:** Found `Array#join('<br/>'.html_safe)` being used to concatenate error messages in mailer views. This pattern completely bypasses Rails' HTML escaping mechanism for the individual array elements, allowing potential Cross-Site Scripting (XSS) if error messages reflect unsanitized user input (e.g. project names, module names, or field values).
**Learning:** Calling `.join` with an `.html_safe` separator returns an `.html_safe` string *without* escaping the items being joined. This is a common but dangerous anti-pattern in Rails.
**Prevention:** Always use Rails' built-in `safe_join(array, '<br/>'.html_safe)` instead. `safe_join` properly HTML-escapes each individual element in the array *before* joining them with the separator.
