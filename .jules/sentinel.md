## 2024-05-24 - SQL Injection via string interpolation in Category#destroy
**Vulnerability:** In `app/models/category.rb`, `Category#destroy` used string interpolation in a raw SQL string to reassign work packages: `WorkPackage.where("category_id = #{id}").update_all("category_id = #{reassign_to.id}")`.
**Learning:** This is a vulnerability if user input reaches `reassign_to.id` (even if it's currently an integer from a related model) and is generally an unsafe practice in Rails.
**Prevention:** Always use parameterized queries (e.g. hash syntax) for `where` and `update_all`: `WorkPackage.where(category_id: id).update_all(category_id: reassign_to.id)`.

## 2024-05-24 - Cross-Site Scripting (XSS) via Array#join and html_safe
**Vulnerability:** Several helper methods (e.g., `settings_matrix_tds`, `labeled_check_box_tags`) were using `array.join.html_safe` instead of `safe_join(array)`. When using `array.join.html_safe`, HTML escaping for the array elements is bypassed, meaning any user input within the array is rendered unsanitized, leading to an XSS vulnerability.
**Learning:** `Array#join` combined with `.html_safe` is an anti-pattern in Rails for constructing HTML strings containing dynamically generated components.
**Prevention:** Always use Rails' built-in `safe_join(array)` method when joining an array of strings that should be rendered as HTML, which correctly ensures that only components explicitly marked as safe are unescaped.
