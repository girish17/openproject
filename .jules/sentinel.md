## 2024-05-24 - SQL Injection via string interpolation in Category#destroy
**Vulnerability:** In `app/models/category.rb`, `Category#destroy` used string interpolation in a raw SQL string to reassign work packages: `WorkPackage.where("category_id = #{id}").update_all("category_id = #{reassign_to.id}")`.
**Learning:** This is a vulnerability if user input reaches `reassign_to.id` (even if it's currently an integer from a related model) and is generally an unsafe practice in Rails.
**Prevention:** Always use parameterized queries (e.g. hash syntax) for `where` and `update_all`: `WorkPackage.where(category_id: id).update_all(category_id: reassign_to.id)`.
