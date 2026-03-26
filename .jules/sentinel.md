## 2024-05-24 - SQL Injection via string interpolation in Category#destroy
**Vulnerability:** In `app/models/category.rb`, `Category#destroy` used string interpolation in a raw SQL string to reassign work packages: `WorkPackage.where("category_id = #{id}").update_all("category_id = #{reassign_to.id}")`.
**Learning:** This is a vulnerability if user input reaches `reassign_to.id` (even if it's currently an integer from a related model) and is generally an unsafe practice in Rails.
**Prevention:** Always use parameterized queries (e.g. hash syntax) for `where` and `update_all`: `WorkPackage.where(category_id: id).update_all(category_id: reassign_to.id)`.

## 2024-05-24 - SQL Injection via string interpolation in Repository#committer_ids=
**Vulnerability:** In `app/models/repository.rb`, `Repository#committer_ids=` used string interpolation in a raw SQL string to update user_ids: `Changeset.where(...).update_all("user_id = #{new_user_id.nil? ? 'NULL' : new_user_id}")`.
**Learning:** This is an unsafe practice in Rails, even when `new_user_id` is coerced to an integer before the interpolation. Using string interpolation in `update_all` is bad practice and could lead to SQL injection if input sanitization is bypassed.
**Prevention:** Always use parameterized queries (e.g. hash syntax) for `update_all`: `.update_all(user_id: new_user_id)`.
